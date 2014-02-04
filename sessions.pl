#!/usr/bin/perl

use strict;
use warnings;

use Waiter;
use WaiterWWW;
use POSIX qw/strftime/;

my $session = Waiter::WWW::load_session('Waiter');
my $data = Waiter::WWW::read_params($session);

if (Waiter::auth_user($$data{username},$$data{hash})) {
    my $userid = Waiter::get_userid($$data{username});
    if ($$data{session} and ($$data{session} ne '')) {
        $$data{session_key} = $$data{session};
        if (Waiter::is_session_owner($userid,$$data{session_key})) {
            session_modify_page($$data{session_key});
        } else {
            session_list_page('You cannot view that session.');
        }
    } elsif ($$data{save}) {
        my @options = Waiter::WWW::prepare_session($data);
        if (Waiter::update_session(@options)) {
            session_list_page("$$data{session_key} updated successfully.");
        } else {
            session_list_page("Session update failed.");
        }
    } elsif ($$data{increase} or $$data{decrease}) {
        my $mod_time = Waiter::convert_to_seconds(
            $$data{weeks_mod},$$data{days_mod},$$data{hours_mod}
        );
        my $time = sprintf('%02dw %02dd %02dh',$$data{weeks_mod},
                        $$data{days_mod},$$data{hours_mod});
        my $direction = 'Incresed';
        if ($$data{decrease}) {
            $mod_time = $mod_time * -1;
            $direction = 'Decreased';
        }
        if (Waiter::update_end_time($$data{session_key},$mod_time)) {
            session_list_page("$$data{session_key}: $direction time by $time");
        }
    } else {
        session_list_page();
    }
} else {
    # Non authenticated session, send to login page.
    print $session->header(
        -location   => 'index.pl'
    );
}

Waiter::WWW::save_session($session, $data);
exit;

sub session_modify_page {
    # Page for modifying a session
    my $session_key = shift;

    my $session = Waiter::get_session_by_key($session_key);
    my $waiter = Waiter::get_username($$session{waiterid});
    my $details = "Editing Session: '$session_key' Waiter: $waiter";
    my $time = time;
    my $session_start = strftime("%F %T",localtime($$session{start_time}));
    my $waited_secs = abs($$session{start_time} - time);
    my $remain_secs = abs($$session{end_time} - time);
    my $waited_time = Waiter::human_time($waited_secs);
    my $remain_time = Waiter::human_time($remain_secs);

    my %checked = ();
    foreach my $time (split(/:/,$$session{vote_times})) {
        $checked{"time_$time"} = 'checked';
    }
    # Create the drop down selectors for setting wait duration
    my $min_list = Waiter::WWW::time_dropdown(
        'min','Minimum Wait Time',$$session{min_time}
    );
    my $max_list = Waiter::WWW::time_dropdown(
        'max','Maximum Wait Time',$$session{max_time}
    );
    my $mod_list = Waiter::WWW::time_dropdown(
        'mod','Adjust Time Remaining',0);
    # Create the checkboxes for voting options
    my $time_checkboxes = Waiter::WWW::time_checkboxes($$session{vote_times});
    my $vote_options = Waiter::WWW::vote_options(
        $$session{min_votes},$$session{vote_cooldown},$$session{msg_times}
    );
    my $misc_options = Waiter::WWW::misc_options(
        $$session{init_rand},$$session{time_past},$$session{time_left}
    );

    Waiter::WWW::page_header($details,1);
    print qq|
    <div class='status'>
    <span class='left'>$waiter Has Waited:</span>
    <span class='right'>$waited_time</span>
    </div>
    <div class='status'>
    <span class='left'>Time Remaining:</span>
    <span class='right'>$remain_time</span>
    </div>
    <div class='status'>
    <span class='left'>Session Started:</span>
    <span class='right'>$session_start</span>
    </div>
    <form method='post'>

    <hr/>
     <table class='options'>
        $min_list
        $max_list
        $mod_list
        <tr>
          <td align='left'>
            <input type='submit' name='increase' value='Increase Wait'>
          </td>
          <td>&nbsp;</td>
          <td align='right'>
            <input type='submit' name='decrease' value='Decrease Wait'>
          </td>
        </tr>
      </table>
      <hr/>
      <table class='options'>
        <caption>Voting Time Options</caption>
        $time_checkboxes
      </table>
      <table class='options'>
        $vote_options
      </table>
      <hr/>
      $misc_options
      <hr/>
      <table class='options'>
        <tr valign='center'>
          <td align='left'>
            Safeword:
          </td>
          <td align='right'>
            <input type='text' name='safeword' value='$$session{safeword}'>
          </td>
        </tr>
        <tr valign='center'>
          <td align='left'>
            &nbsp;
          </td>
          <td align='right'>
            <input type='submit' name='save' value='Save'>
            <input type='hidden' name='session_key' value='$session_key'>
          </td>
        </tr>
      </table>
    </form>
|;
    Waiter::WWW::page_footer();
}

sub session_list_page {
    my $error = shift || '';

    my $userid = Waiter::get_userid($$data{username});
    my @sessions = Waiter::get_user_sessions($userid);
    my $html = '';
    foreach my $key (@sessions) {
        my $session = Waiter::get_session_by_key($key);
        my $waiter = Waiter::get_username($$session{waiterid});
        my $name = $key;
        if ($$session{name}) {
            $name = $$session{name};
        }
        $html .= qq|
    <tr valign='center'>
      <td align='left'>$key</td>
      <td align='left'>$name</td>
      <td align='left'>$waiter</td>
      <td align='right'><a href='sessions.pl?session=$key'>Modify</a>
    </tr>
|;
    }
    if ($html eq '') {
        $html = qq|
    <tr valign='top'>
      <td>No Sessions Found</td>
      <td>&nbsp;</td>
      <td>&nbsp;</td>
    </tr>
|;
    } else {
        $html = qq|
    <tr valign='center'>
      <td align='left'>Session Key</td>
      <td align='left'>Session Name</td>
      <td align='left'>Waiter Name</td>
      <td>&nbsp;</td>
    </tr>
    $html
|;
    }

    Waiter::WWW::page_header('Your Sessions',1);
    print qq|
    <table class='options'>
    $html
    </table>
    <br/>
    <br/>
|;
    Waiter::WWW::page_footer($error);
}
