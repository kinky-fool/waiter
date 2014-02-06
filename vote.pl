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
        my $waiter = Waiter::get_display_name($userid);
        my $sessionid = Waiter::get_sessionid_active($userid);
        if ($sessionid) {
            voting_page($sessionid,$waiter,$data);
        } else {
            simple_page("$waiter is not currently waiting.");
        }
    } else {
        simple_page("Unable to find user matching $$data{key}.");
    }
} else {
    # There's room here for randomly picking someone to vote for...
    simple_page("No user information provided.");
}

exit;

sub simple_page {
    my $message = shift;

    Waiter::WWW::page_header('Waiting Game Voting',1);
    print "<p>$message</p>";
    Waiter::WWW::page_footer();
}

sub voting_page {
    my $sessionid   = shift;
    my $waiter      = shift;
    my $data        = shift;

    my $session = Waiter::get_session($sessionid);
    my $vote_count = Waiter::get_votes($sessionid);

    my $vote_time = 0;
    if ($$data{cast_vote}) {
        my $vote = $$data{vote_choice};
        my @vote_times = split(/:/,$$session{vote_times});
        if ($vote eq 'rand') {
            $vote = $vote_times[rand(@vote_times)];
        } elsif ($vote eq 'randadd') {
            my @times = grep {/^[0-9]+/} @vote_times;
            $vote = $times[rand(@times)];
        } elsif ($vote eq 'randsub') {
            my @times = grep {/^-[0-9]+/} @vote_times;
            $vote = $times[rand(@times)];
        }
        if (grep {/^$vote$/} @vote_times) {
            # Verify that the time selected is valid no cheaters!
            $vote_time = $vote;
        }
    }

    # Openshift does some weird stuff to IPs
    my $ip = $$data{HTTP_X_CLIENT_IP};
    $ip = $$data{REMOTE_ADDR} unless ($ip and $ip ne '');

    my $last_voted = Waiter::last_vote_time_by_ip($ip,$sessionid);
    my $cooldown = $$session{vote_cooldown} * 60 * 60;
    my $vote_html = '';
    if (abs($last_voted - time) > $cooldown) {
        if ($$data{cast_vote} and ($vote_time != 0)) {
            my $seconds = $vote_time * 60 * 60;
            Waiter::cast_vote($sessionid,$ip,$seconds,$$data{voter_name});
            my $verb = 'Increased';
            if ($vote_time < 0) {
                $verb = 'Decreased';
                $vote_time = abs($vote_time);
            }
            $vote_html = "<p>$verb ${waiter}'s wait by $vote_time hours</p>";
        } else {
            $vote_html = Waiter::WWW::vote_choice(
                            $$session{vote_times},$waiter,$$data{key});
        }
    } else {
        my $next_vote = Waiter::human_time($last_voted+$cooldown-time);
        $vote_html = qq|
        <div class='status'>
        <span class='left'>You may vote again in $next_vote</span>
        </div>|;
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

    my $min_time = $$session{start_time} + $$session{min_time};
    my $max_time = $$session{start_time} + $$session{max_time};
    $min_time = POSIX::strftime("%F %T %Z",localtime($min_time));
    $max_time = POSIX::strftime("%F %T %Z",localtime($max_time));

    my $status_html = qq|
    <div class='status'>
    <span class='left'>$waiter Has Waited:</span>
    <span class='right'>$time_past</span>
    </div>
    <div class='status'>
    <span class='left'>Time Remaining:</span>
    <span class='right'>$time_left</span>
    </div>
    <div class='status'>
    <span class='left'>Earliest Possible End:</span>
    <span class='right'>$min_time</span>
    </div>
    <div class='status'>
    <span class='left'>Latest Possible End:</span>
    <span class='right'>$max_time</span>
    </div>
|;

    my $min_votes = '';
    if ($$session{min_votes} > $vote_count) {
        my $votes_needed = $$session{min_votes} - $vote_count;
        $min_votes = sprintf("%s %s %s","$waiter needs $votes_needed",
                            ($votes_needed==1)?"person":"people",
                            "to vote to finish waiting.");
        $min_votes = qq|
    <br/>
    <p>$min_votes</p>
    <br/>
|;
    }

    Waiter::WWW::page_header('Waiting Game Voting',1);
    print qq|
    $status_html
    $min_votes
    $vote_html
    <br/>
|;
    Waiter::WWW::page_footer();
}
