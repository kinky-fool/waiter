#!/usr/bin/perl

use strict;
use warnings;

use CGI qw/:standard/;
use CGI::Carp qw/fatalsToBrowser/;
use CGI::Session qw/-ip_match/;

package Waiter::WWW;

sub login {
    # Create the cookie and such.
    my $session = shift;

    if ($session->is_empty) {
        $session = $session->new() or die $session->errstr;
    }
    $session->expire('~logged-in', '30m');
    $session->flush();

    my $cgi = CGI->new;
    my $cookie = $cgi->cookie(
        -name       => $session->name,
        -value      => $session->id
    );
    print $session->header(
            -location   => 'home.pl',
            -cookie     => $cookie
    );
}

sub logout {
    my $session = shift;

    $session->delete();
    $session->flush();
    print $session->header(
        -location   => 'index.pl'
    );
}

sub load_session {
    # Read session information and return the information as a hashref
    my $sess_name = shift;

    CGI::Session->name($sess_name);
    my $session = CGI::Session->load();
    return $session;
}

sub read_params {
    # Read session information and return the information as a hashref
    my $session = shift;

    my %data = ();
    # Read session parameters
    foreach my $key ($session->param()) {
        $data{$key} = $session->param($key);
    }
    # Read CGI parameters
    foreach my $key (CGI::param()) {
        $data{$key} = CGI::param($key);
    }
    # Attempt to replace 'password' with 'hash'
    if ($data{username} and $data{password}) {
        $data{hash} = Waiter::make_hash($data{username},$data{password});
        delete $data{password};
    }
    return \%data;
}

sub save_session {
    # Take in the settings hash and store them in the session
    my $session = shift;
    my $data    = shift;

    # Clear the params
    $session->clear();
    if ($$data{username} and ($$data{username} ne '')) {
        $session->param('username', $$data{username});
    }
    if ($$data{hash} and ($$data{hash} ne '')) {
        $session->param('hash', $$data{hash});
    }
    $session->expire('~logged-in', '30m');

    $session->flush();
}

sub prepare_recipe {
    # Take recipe data in from the web and format it as needed
    my $data    = shift;

    my $userid = Waiter::get_userid($$data{username});

    # Convert dropdown times to seconds
    my $start_time = Waiter::convert_to_seconds(
        $$data{weeks_start},$$data{days_start},$$data{hours_start}
    );
    my $min_time = Waiter::convert_to_seconds(
        $$data{weeks_min},$$data{days_min},$$data{hours_min}
    );
    my $max_time = Waiter::convert_to_seconds(
        $$data{weeks_max},$$data{days_max},$$data{hours_max}
    );

    # Voting Times
    my @v_times;
    foreach my $key (keys %$data) {
        if ($key =~ /^sub_([0-9]+)$/) {
            push(@v_times,"-$1");
        }
        if ($key =~ /^add_([0-9]+)$/) {
            push(@v_times,"$1");
        }
    }
    my $vote_times = join(':',@v_times);

    my $min_votes = 0;
    if ($$data{min_votes} and ($$data{min_votes} =~ /^[0-9]+$/)) {
        $min_votes = $$data{min_votes} if ($$data{min_votes});
    }
    my $msg_times = 0;
    if ($$data{msg_times}) {
        $msg_times = 1;
    }

    return ($userid,$$data{recipe_key},$$data{name},$min_time,$max_time,
            $start_time,$$data{start_rand},$min_votes,$vote_times,
            $$data{cooldown},$$data{time_past},$$data{time_left},$msg_times,
            $$data{safeword});
}

sub page_header {
    my $title   = shift;
    my $logout  = shift || 0;

    my $logout_link = '';
    if ($logout) {
        $logout_link = "<p id='logout'><a href='logout.pl'>logout</a></p>";
    }
    print <<ENDL;
Content-Type: text/html; charset=ISO-8859-1
Cache-Control: no-cache, no-store, must-revalidate

<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN" "http://www.w3.org/TR/html4/strict.dtd">
<html>
  <head>
    <meta name="viewport" content="width=device-width, initial-scale=1.0;">
    <meta name="apple-mobile-web-app-capable" content="yes">
    <meta name="apple-mobile-web-app-status-bar-style" content="black">
    <title>$title</title>
    <meta http-equiv="Content-Type" content="text/html; charset=iso-8859-1">
    <style type="text/css">\@import "style.css";</style>
  </head>
  <body>
  <div id='container'>
    $logout_link
    <h4>$title</h4>
ENDL
}

sub page_footer {
    my $error   = shift || '';
    $error = "<p><em>$error</em></p>" if ($error ne '');

    print qq|
    $error
  </div>
  </body>
</html>
|;
}

sub time_dropdown {
    # Produce HTML for weeks/days/hours selector
    my $type    = shift || '';
    my $caption = shift || '';
    my $seconds = shift;

    my ($weeks,$days,$hours) = Waiter::convert_from_seconds($seconds);

    my $html = qq|
      <tr valign='center'>
        <td align='left' colspan='2'>$caption</td>
        <td>&nbsp;</td>
      </tr>
      <tr valign='center'>
        <td align='left'>
          <select name='weeks_$type'>
|;
    for my $i (0 .. 52) {
        my $selected = '';
        $selected = ' selected' if ($i == $weeks);
        $html .= sprintf("            <option value='%d'%s>%d %s</option>\n",
                $i,$selected,$i,($i == 1)?'Week':'Weeks');
    }
    $html .= qq|          </select>
        </td><td align='center'>
          <select name='days_$type'>
|;
    for my $i (0 .. 6) {
        my $selected = '';
        $selected = ' selected' if ($i == $days);
        $html .= sprintf("            <option value='%d'%s>%d %s</option>\n",
                $i,$selected,$i,($i == 1)?'Day':'Days');
    }
    $html .= qq|          </select>
        </td><td align='right'>
          <select name='hours_$type'>
|;
    for my $i (0 .. 23) {
        my $selected = '';
        $selected = ' selected' if ($i == $hours);
        $html .= sprintf("            <option value='%d'%s>%d %s</option>\n",
                $i,$selected,$i,($i == 1)?'Hour':'Hours');
    }
    $html .= qq|          </select>
        </td>
      </tr>
|;
    return $html;
}

sub time_checkboxes {
    # Generate HTML for time checkboxes.
    my $times = shift;

    my %adds = ();
    my %subs = ();
    foreach my $time (split(/:/,$times)) {
        if ($time =~ /^[0-9-]+$/) {
            if ($time > 0) {
                $adds{$time} = ' checked';
            } else {
                $subs{abs($time)} = ' checked';
            }
        }
    }
    my $html = qq|
      <tr valign='center'>
        <td align='left'>Decrease</td>
        <td>&nbsp;</td>
        <td align='right'>Increase</td>
      </tr>
|;
    foreach my $time (1,2,4,8,12) {
        $html .= qq|
      <tr valign='center'>
        <td align='left'>
          <input type='checkbox' name='sub_$time' $subs{$time} />
        </td>
        <td align='center'>
          $time hours
        </td>
        <td align='right'>
          <input type='checkbox' name='add_$time' $adds{$time} />
        </td>
      </tr>
|;
    }
    return $html;
}

sub vote_options {
    my $min         = shift;
    my $cooldown    = shift;
    my $msg_times   = shift;

    my $mtchecked = '';
    $mtchecked = ' checked' if ($msg_times > 0);

    my $html = qq|
      <tr valign='center'>
        <td align='left'>Required Votes</td>
        <td align='right'>Vote Cooldown</td>
      <tr>
      <tr valign='center'>
        <td align='left'>
          <input type='text' name='min_votes' size=11 value='$min'>
        </td>
        <td align='right'>
          <select name='cooldown'>
|;
    for my $i (24,18,12,6,4,2,1) {
        my $selected = '';
        $selected = ' selected' if ($i == $cooldown);
        $html .= sprintf("            <option value='%d'%s>%d %s</option>\n",
                $i,$selected,$i,($i == 1)?'Hour':'Hours');
    }
    $html .= qq|          </select>
        </td>
      </tr>
      <tr valign='center'>
        <td align='left'>
            <label for='msg_times'>Show Times in Messages</label>
        </td>
        <td align='right'>
            <input type='checkbox' id='msg_times' name='msg_times'$mtchecked>
        </td>
      </tr>
|;
    return $html;
}

sub misc_options {
    my $start_rand  = shift;
    my $time_past   = shift;
    my $time_left   = shift;
    my $safeword    = shift;

    my %ck = (
        "sr$start_rand" => ' checked',
        "tp$time_past"  => ' checked',
        "tl$time_left"  => ' checked',
    );

    my $html = qq|
    <table class='options'>
      <tr valign='center'>
        <td align='left'>
          <label for='sr0'>Don't Randomize Start Time</label>
        </td>
        <td align='right'>
          <input type='radio' id='sr0' name='start_rand' value='0' $ck{sr0} />
        </td>
      </tr>
      <tr valign='center'>
        <td align='left'>
          <label for='sr1'>Random Start Time (Zero to Start Time)</label>
        </td>
        <td align='right'>
          <input type='radio' id='sr1' name='start_rand' value='1' $ck{sr1} />
        </td>
      </tr>
      <tr valign='center'>
        <td align='left'>
          <label for='sr2'>Random Start Time; Low End of Start Time</label>
        </td>
        <td align='right'>
          <input type='radio' id='sr2' name='start_rand' value='2' $ck{sr2} />
        </td>
      </tr>
      <tr valign='center'>
        <td align='left'>
          <label for='sr3'>Random Start Time; High End of Start Time</label>
        </td>
        <td align='right'>
          <input type='radio' id='sr3' name='start_rand' value='3' $ck{sr3} />
        </td>
      </tr>
    </table>
    <hr/>
    <table class='options'>
      <tr valign='center'>
        <td align='left'>
          <label for='tp0'>Hide Time Spent Waiting</label>
        </td>
        <td align='right'>
          <input type='radio' id='tp0' name='time_past' value='0' $ck{tp0} />
        </td>
      </tr>
      <tr valign='center'>
        <td align='left'>
          <label for='tp1'>Show Time Spent Waiting</label>
        </td>
        <td align='right'>
          <input type='radio' id='tp1' name='time_past' value='1' $ck{tp1} />
        </td>
      </tr>
      <tr valign='center'>
        <td align='left'>
          <label for='tp2'>Show 'Approximate' Time Spent Waiting</label>
        </td>
        <td align='right'>
          <input type='radio' id='tp2' name='time_past' value='2' $ck{tp2} />
        </td>
      </tr>
    </table>
    <hr/>
    <table class='options'>
      <tr valign='center'>
        <td align='left'>
          <label for='tl0'>Hide Time Remaining</label>
        </td>
        <td align='right'>
          <input type='radio' id='tl0' name='time_left' value='0' $ck{tl0} />
        </td>
      </tr>
      <tr valign='center'>
        <td align='left'>
          <label for='tl1'>Show Time Remaining</label>
        </td>
        <td align='right'>
          <input type='radio' id='tl1' name='time_left' value='1' $ck{tl1} />
        </td>
      </tr>
      <tr valign='center'>
        <td align='left'>
          <label for='tl2'>Show 'Approximate' Time Remaining</label>
        </td>
        <td align='right'>
          <input type='radio' id='tl2' name='time_left' value='2' $ck{tl2} />
        </td>
      </tr>
    </table>
|;
    return $html;
}

sub information_html {
    # Produce a block of HTML that shows a users' basic information
    my $user    = shift;

    my $userid = Waiter::get_userid($user);
    my $information = '';
    if (my $session = Waiter::is_waiting($userid)) {
        $information = "<h3>In a Session</h3>";
    } else {
        $information = "<h3>Not in a Session</h3>";
    }
    return $information;
}

sub messages_html {
    # Produce a block of HTML to display messages for a user
    my $user    = shift;

    my $userid = Waiter::get_userid($user);
    my $messages = '';
    return $messages;
}

1;
__END__
