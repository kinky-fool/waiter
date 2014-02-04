#!/usr/bin/perl

use strict;
use warnings;

use Waiter;
use WaiterWWW;

my $session = Waiter::WWW::load_session('Waiter');
my $data = Waiter::WWW::read_params($session);

if ($$data{key}) {
    my $userid = Waiter::get_userid_by_key($$data{key});
    if ($userid) {
        my $sessionid = Waiter::get_sessionid_active($userid);
        if ($sessionid) {
            # valid key provided, display voting page
            voting_page($sessionid);
        } else {
            # Not waiting
        }

    } else {
        # No user found
    }
} else {
    # No key / vote cast
}

Waiter::WWW::save_session($session, $data);
exit;

sub voting_page {
    my $sessionid   = shift;

    my $session = Waiter::get_session($sessionid);
    my $waiter = Waiter::get_display_name($$session{waiterid});
    my $vote_count = Waiter::get_votes($sessionid);

    my $min_votes = '';
    if ($$session{min_votes} > $vote_count) {
        my $votes_needed = $$session{min_votes} - $vote_count;
        $min_votes .= "$waiter needs $votes_needed votes to finish waiting.";
    }

    my $waited_time = abs($$session{start_time} - time);
    my $time_past = 'Information hidden by session settings.';
    if ($$session{time_past} == 1) {
        $time_past = Waiter::human_time($waited_time);
    } elsif ($$session{time_past} == 2) {
        $time_past = Waiter::approx_time($waited_time);
    }

    my $remain_time = $$session{end_time} - time;
    my $time_left = 'Information hidden by session settings.';
    if ($remain_time > 0) {
        if ($$session{time_left} == 1) {
            $time_left = Waiter::human_time($remain_time);
        } elsif ($$session{time_left} == 2) {
            $time_left = Waiter::approx_time($remain_time);
        }
    } else {
        $time_left = 'Wait is over, voting is still possible.';
    }

    my $last_voted = Waiter::last_vote_time_by_ip($$data{REMOTE_ADDR});
    my $cooldown = $$session{vote_cooldown} * 60 * 60;
    my $vote_html = '';
    if (abs($last_voted - time) > $cooldown) {
        $vote_html = Waiter::WWW::vote_choice($$session{vote_times});
    } else {
        # can't vote :(
    }

    Waiter::WWW::page_header('Waiting Game Voting',1);
    print qq|
    <div class='status'>
    <span class='left'>$waiter Has Waited:</span>
    <span class='right'>$time_past</span>
    </div>
    <div class='status'>
    <span class='left'>Time Remaining:</span>
    <span class='right'>$time_left</span>
    </div>
    <br/><br/>
    <form method='post'>
    <div class='status'>
      <span class='left'>
        Let $waiter know who to thank or curse:
      </span>
      <span class='right'>
        <input type='text' size='13' name='voter_name' value='anonymous'>
      </span>
    </div>
    $vote_html
    </form>
    <br/><br/>
    <p>$min_votes</p>
|;
    Waiter::WWW::page_footer();
}
