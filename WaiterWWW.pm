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
    $session->expire('~logged-in', '1w');
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

    # Read CGI ENV
    foreach my $key (keys %ENV) {
        $data{$key} = $ENV{$key};
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
    $session->expire('~logged-in', '1w');

    $session->flush();
}

sub prepare_recipe {
    # Take recipe data in from the web and format it as needed
    my $data    = shift;

    my $userid = Waiter::get_userid($$data{username});

    # Convert dropdown times to seconds
    my $init_time = Waiter::convert_to_seconds(
        $$data{weeks_init},$$data{days_init},$$data{hours_init}
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
            $init_time,$$data{init_rand},$min_votes,$vote_times,
            $$data{cooldown},$$data{time_past},$$data{time_left},$msg_times,
            $$data{safeword});
}

sub prepare_session {
    # Take session data in from the web and format it as needed
    my $data    = shift;

    my $userid = Waiter::get_userid($$data{username});

    # Convert dropdown times to seconds
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

    return ($userid, $$data{session_key}, $min_time, $max_time,
            $min_votes, $vote_times, $$data{cooldown}, $$data{time_past},
            $$data{time_left}, $msg_times, $$data{safeword});
}

sub page_header {
    my $title       = shift;
    my $show_links  = shift || 0;

    my $links = '';
    if ($show_links) {
        $links = qq|
        <p id='top_links'>
        <a href='home.pl'>Home</a>
        &nbsp;&nbsp;&nbsp;&nbsp;
        &nbsp;&nbsp;&nbsp;&nbsp;
        <a href='recipes.pl'>Manage Recipes</a>
        &nbsp;&nbsp;&nbsp;&nbsp;
        &nbsp;&nbsp;&nbsp;&nbsp;
        <a href='sessions.pl'>Manage Sessions</a>
        &nbsp;&nbsp;&nbsp;&nbsp;
        &nbsp;&nbsp;&nbsp;&nbsp;
        <a href='settings.pl'>Settings</a>
        &nbsp;&nbsp;&nbsp;&nbsp;
        &nbsp;&nbsp;&nbsp;&nbsp;
        <a href='logout.pl'>logout</a>
        </p>
        |;
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
    <div id='header_links'>
    $links
    </div>
    <h2>$title</h2>
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
    for my $i (0 .. 12) {
        $adds{$i} = '';
        $subs{$i} = '';
    }
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

sub radio_options {
    # Generate HTML for radio buttons options
    my $name    = shift;
    my $check   = shift;
    my @choices = @_;

    my $html = '';
    foreach my $choice (@choices) {
        my ($text,$id,$value) = split(/:/,$choice);
        my $checked = '';
        $checked = ' checked' if ($value == $check);
        $html .= qq|
    <tr>
      <td align='left'>
        <label for='$id$value'>$text</label>
      <td>
      <td align='right'>
        <input type='radio' id='$id$value' name='$name' value='$value'$checked>
      </td>
    </tr>|;
    }
    return $html;
}

sub vote_choice {
    # Generate dropdown to present to voters
    my $vtimes      = shift;
    my $waiter      = shift;
    my $user_key    = shift;

    my @times = sort {$a <=> $b} (split/:/,$vtimes);
    my $select = $times[rand(@times)];
    my $html = qq|
    <form method='post'>
    <div class='status'>
      <span class='left'>
        Let $waiter know who to thank or curse:
      </span>
      <span class='right'>
        <input type='text' size='13' name='voter_name' value='anonymous'>
      </span>
    </div>
    <div class='status'>
      <span class='left'>
        <select name='vote_choice'>|;
    foreach my $time (@times) {
        my $abstime = abs($time);
        my $selected = '';
        $selected = ' selected' if ($time == $select);
        my $verb = 'Increase';
        if ($time < 0) {
            $verb = 'Decrease';
        }
        $html .= qq|
          <option value='$time'$selected>$verb wait by $abstime hours</option>
|;
    }
    $html .= qq|
          <option value='rand'>Select at Random</option>
          <option value='randsub'>Select Random Decrease</option>
          <option value='randadd'>Select Random Increase</option>
        </select>
      </span>
      <span class='right'>
        <input type='hidden' name='key' value='$user_key'>
        <input type='submit' name='cast_vote' value='Cast Your Vote'>
      </span>
    </div>
    </form>
|;
    return $html;
}

sub session_status {
    my $sessionid   = shift;

    my $session = Waiter::get_session($sessionid);
    my $trustee = Waiter::get_display_name($$session{trusteeid});
    my $user_key = Waiter::get_user_key($$session{waiterid});
    my $votes   = Waiter::get_votes($sessionid);
    my $vote_url = "http://" . CGI::server_name() . "/vote.pl?key=$user_key";

    my $html = "<p>You are waiting for $trustee";
    my $waited_time = abs($$session{start_time} - time);
    if ($$session{time_past} > 0) {
        my $waited = Waiter::human_time($waited_time);
        if ($$session{time_past} == 2) {
            $waited = Waiter::approx_time($waited_time);
        }
        $html .= "<p>You have been waiting $waited.</p>";
    }

    my $remaining = $$session{end_time} - time;
    if ($remaining > 0) {
        if ($$session{time_left} > 0) {
            my $time_left = Waiter::human_time($remaining);
            if ($$session{time_left} == 2) {
                $time_left = Waiter::approx_time($remaining);
            }
            $html .= "<p>You must wait $time_left longer.</p>";
        } else {
            $html .= "<p>You must continue waiting.</p>";
        }
    } else {
        $remaining = 0;
    }
    if ($$session{min_votes} > $votes) {
        my $votes_needed = $$session{min_votes} - $votes;
        $html .= qq|<p>$votes_needed people need to vote
                    before you may end your wait.</p>|;
    } elsif ($remaining == 0) {
        $html .= qq|
    <p>Your wait is over!</p>
    <form method='post'>
    <input type='submit' name='finish' value='End Wait!'/>
    </form>
|;
    }
    $html .= "<p>Voting Link: <a href='$vote_url'>$vote_url</a></p>";

    return $html;
}

sub messages_html {
    # Produce a block of HTML to display messages for a user
    my $userid    = shift;

    my $messages = Waiter::get_messages($userid);
    my $html = '';
    foreach my $id (sort keys %$messages) {
        $html .= qq|
        <tr>
          <td>$$messages{$id}{time}</td>
          <td>$$messages{$id}{sender}</td>
          <td>$$messages{$id}{message}</td>
        </tr>
|;
    }
    return $html;
}

1;
__END__
