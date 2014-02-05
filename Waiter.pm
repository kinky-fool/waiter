#!/usr/bin/perl

use strict;
use warnings;

use DBI;
use POSIX qw(strftime);

package Waiter;

my $db_user = 'waiter';
my $db_pass = 'patience';
my $db_name = 'waiting_game';
my $db_host = 'localhost';

sub db_connect {
    my $dsn = "dbi:mysql:database=$db_name;host=$db_host";
    my $dbh = DBI->connect($dsn,$db_user,$db_pass,{ RaiseError => 1 })
                or die "Failed to connect to database: $DBI::errstr";
    return $dbh;
}

sub logger {
    # TODO
    my $message = shift;

    return;
}

sub make_hash {
    # Psuedo authentication; return a hash
    # If the right password is provided, the right hash will be returned
    my $user    = shift;
    my $pass    = shift;

    my $hash = get_hash($user);
    if ($hash and (crypt($pass,$hash) eq $hash)) {
        return $hash;
    }
    # Return something that looks like a hash, but is incorrect
    return crypt($pass,$user);
}

sub get_hash {
    # Return the stored hash for a user
    my $user    = shift;

    my $sql = qq| select password from users where username = ? |;
    my $dbh = db_connect();
    my $sth = $dbh->prepare($sql);
    $sth->execute($user);
    my ($hash) = $sth->fetchrow_array();
    $sth->finish();
    $dbh->disconnect();
    if ($hash and ($hash ne '')) {
        return $hash;
    }
    return;
}

sub auth_user {
    # Authenticate a user login
    my $user    = shift;
    my $hash    = shift;

    my $correct = get_hash($user);
    if ($correct and $hash and ($hash eq $correct)) {
        return 1;
    }

    logger("Login failed for '$user'; invalid password");
    return;
}

sub get_userid {
    # Return a user's userid using a username
    my $user    = shift;

    my $sql = qq| select userid from users where username = ? |;
    my $dbh = db_connect();
    my $sth = $dbh->prepare($sql);
    $sth->execute($user);
    my ($userid) = $sth->fetchrow_array();
    $sth->finish();
    $dbh->disconnect();
    if ($userid and ($userid ne '')) {
        return $userid;
    }
    return;
}

sub get_sessionid {
    # Lookup sessionid by session_key
    my $session_key = shift;

    my $sql = qq| select sessionid from sessions where session_key = ? |;
    my $dbh = db_connect();
    my $sth = $dbh->prepare($sql);
    $sth->execute($session_key);
    my ($sessionid) = $sth->fetchrow_array();
    $sth->finish();
    $dbh->disconnect();
    if ($sessionid and ($sessionid ne '')) {
        return $sessionid;
    }
    return;
}

sub get_userid_by_key {
    # Return a user's id provided the unique user_key
    my $user_key    = shift;

    my $sql = qq| select userid from users where user_key = ? |;
    my $dbh = db_connect();
    my $sth = $dbh->prepare($sql);
    $sth->execute($user_key);
    my ($userid) = $sth->fetchrow_array();
    $sth->finish();
    $dbh->disconnect();
    if ($userid and ($userid ne '')) {
        return $userid;
    }
    return;
}

sub get_username {
    # Return a username provided a userid
    my $userid  = shift;

    my $sql = qq| select username from users where userid = ? |;
    my $dbh = db_connect();
    my $sth = $dbh->prepare($sql);
    $sth->execute($userid);
    my ($username) = $sth->fetchrow_array();
    $sth->finish();
    $dbh->disconnect();
    if ($username and ($username ne '')) {
        return $username;
    }
    return;
}

sub get_display_name {
    # Return a user's display_name if set, username otherwise
    my $userid  = shift;

    my $sql = qq| select display_name,username from users where userid = ? |;
    my $dbh = db_connect();
    my $sth = $dbh->prepare($sql);
    $sth->execute($userid);
    my ($display_name,$username) = $sth->fetchrow_array();
    $sth->finish();
    $dbh->disconnect();
    if ($display_name and ($display_name ne '')) {
        return $display_name;
    } elsif ($username and ($username ne '')) {
        return $username;
    }
    return;
}

sub get_user_key {
    # Return a user's user_key
    my $userid  = shift;

    my $sql = qq| select user_key from users where userid = ? |;
    my $dbh = db_connect();
    my $sth = $dbh->prepare($sql);
    $sth->execute($userid);
    my ($user_key) = $sth->fetchrow_array();
    $sth->finish();
    $dbh->disconnect();
    if ($user_key and ($user_key ne '')) {
        return $user_key;
    }
    return;
}

sub get_sessionid_active {
    # Return sessionid if a user is currently in a session
    my $userid  = shift;

    my $sql = qq| select sessionid from sessions where
                        finished = 0 and waiterid = ? |;
    my $dbh = db_connect();
    my $sth = $dbh->prepare($sql);
    $sth->execute($userid);
    my ($sid) = $sth->fetchrow_array();
    $sth->finish();
    $dbh->disconnect();
    if ($sid and ($sid ne '')) {
        return $sid;
    }
    return;
}

sub get_user_recipes {
    # Return an array of recipes owned by userid
    my $userid  = shift;
    my $sql = qq| select recipe_key from recipes where ownerid = ? |;
    my $dbh = db_connect();
    my $sth = $dbh->prepare($sql);
    $sth->execute($userid);
    my @recipes = ();
    while (my ($recipe_key) = $sth->fetchrow_array()) {
        push @recipes, $recipe_key;
    }
    $sth->finish();
    $dbh->disconnect();
    return @recipes;
}

sub get_user_sessions {
    # Return an array of session_keys owned by userid
    my $userid  = shift;
    my $sql = qq| select session_key from sessions where trusteeid = ? |;
    my $dbh = db_connect();
    my $sth = $dbh->prepare($sql);
    $sth->execute($userid);
    my @session_keys = ();
    while (my ($session_key) = $sth->fetchrow_array()) {
        push @session_keys, $session_key;
    }
    $sth->finish();
    $dbh->disconnect();
    return @session_keys;
}

sub get_recipe_by_key {
    # Return a hashref of the recipe settings, if found
    my $recipe_key  = shift;

    my $sql = qq| select * from recipes where recipe_key = ? |;
    my $dbh = db_connect();
    my $sth = $dbh->prepare($sql);
    $sth->execute($recipe_key);
    my $recipe = $sth->fetchrow_hashref();
    $sth->finish();
    $dbh->disconnect();
    if ($recipe) {
        return $recipe;
    }
    return;
}

sub get_session_by_key {
    # Return a hashref of the session settings, if found
    my $session_key  = shift;

    my $sql = qq| select * from sessions where session_key = ? |;
    my $dbh = db_connect();
    my $sth = $dbh->prepare($sql);
    $sth->execute($session_key);
    my $session = $sth->fetchrow_hashref();
    $sth->finish();
    $dbh->disconnect();
    if ($session) {
        return $session;
    }
    return;
}

sub get_session {
    my $sessionid = shift;

    my $sql = qq| select * from sessions where sessionid = ? |;
    my $dbh = db_connect();
    my $sth = $dbh->prepare($sql);
    $sth->execute($sessionid);
    my $session = $sth->fetchrow_hashref();
    $sth->finish();
    $dbh->disconnect();
    if ($session) {
        return $session;
    }
    return;
}

sub get_votes {
    my $sessionid = shift;

    my $sql = qq| select count(*) from votes where sessionid = ? |;
    my $dbh = db_connect();
    my $sth = $dbh->prepare($sql);
    $sth->execute($sessionid);
    my ($votes) = $sth->fetchrow_array();
    $sth->finish();
    $dbh->disconnect();
    return $votes;
}

sub last_vote_time_by_ip {
    # Return the timestamp of an IPs last vote, or 0
    my $ip          = shift;
    my $sessionid   = shift;

    my $sql = qq| select time from votes where ip = ? and sessionid = ?
                    order by time desc limit 1 |;
    my $dbh = db_connect();
    my $sth = $dbh->prepare($sql);
    $sth->execute($ip,$sessionid);
    my ($time) = $sth->fetchrow_array();
    $sth->finish();
    $dbh->disconnect();
    if ($time) {
        return $time;
    }
    return 0;
}

sub get_messages {
    my $userid = shift;

    my $sql = qq| select messageid,sender,time,message from messages
                    where to_id = ? |;
    my $dbh = db_connect();
    my $sth = $dbh->prepare($sql);
    $sth->execute($userid);
    my $messages = $sth->fetchall_hashref('messageid');
    foreach my $id (keys %$messages) {
        $$messages{$id}{time} = POSIX::strftime("%F %T",
                localtime($$messages{$id}{time}));
    }
    $sth->finish();
    $dbh->disconnect();
    return $messages;
}

sub make_user {
    # Create / store user information in the database
    my $user    = shift;
    my $pass    = shift;

    my $sql = qq| select userid from users where username = ? |;
    my $dbh = db_connect();
    my $sth = $dbh->prepare($sql);
    $sth->execute($user);
    my ($uid) = $sth->fetchrow_array();
    $sth->finish();

    if ($uid) {
        logger("Account creation failed: '$user' already exists");
        $dbh->disconnect;
        return;
    }

    my $salt = join '',('.','.',0..9,'A'..'Z','a'..'z')[rand 64, rand 64];
    my $hash = crypt($pass,$salt);

    my $user_key = make_key('users','user_key');

    $sql = qq| insert into users (username,password,user_key) values (?,?,?) |;
    $sth = $dbh->prepare($sql);
    my $rv = $sth->execute($user,$hash,$user_key);
    $sth->finish();
    $dbh->disconnect();
    if ($rv > 0) {
        logger("Account creation success: '$user' created");
        return 1;
    }
    logger("Account creation failed: '$user' DB insert failed");
    return;
}

sub is_recipe_owner {
    # Verify that a user owns the recipe
    my $userid  = shift;
    my $recipe  = shift;

    my $sql = qq| select ownerid from recipes where recipe_key = ? |;
    my $dbh = db_connect();
    my $sth = $dbh->prepare($sql);
    $sth->execute($recipe);
    my ($owner) = $sth->fetchrow_array();
    $sth->finish();
    $dbh->disconnect();
    if ($owner eq $userid) {
        return 1;
    }
    return;
}

sub is_session_owner {
    # Verify that a user owns the session
    my $userid      = shift;
    my $session_key = shift;

    my $sql = qq| select trusteeid from sessions where session_key = ? |;
    my $dbh = db_connect();
    my $sth = $dbh->prepare($sql);
    $sth->execute($session_key);
    my ($owner) = $sth->fetchrow_array();
    $sth->finish();
    $dbh->disconnect();
    if ($owner eq $userid) {
        return 1;
    }
    return;
}

sub delete_recipe {
    my $recipe_key = shift;
    my $sql = qq| delete from recipes where recipe_key = ? |;
    my $dbh = db_connect();
    my $sth = $dbh->prepare($sql);
    my $rv = $sth->execute($recipe_key);
    $sth->finish();
    $dbh->disconnect();
    if ($rv > 0) {
        return 1;
    }
    return;
}

sub create_new_recipe {
    # Create a new default recipe for $userid
    my $userid  = shift;
    my $recipe_key = make_key('recipes','recipe_key');

    my $sql = qq| insert into recipes (ownerid, name, recipe_key)
                    values (?, ?, ?) |;
    my $dbh = db_connect();
    my $sth = $dbh->prepare($sql);
    my $rv = $sth->execute($userid,$recipe_key,$recipe_key);
    $sth->finish();
    $dbh->disconnect();
    if ($rv > 0) {
        return $recipe_key;
    }
    return;
}

sub update_recipe {
    # Update the settings of a recipe
    my $ownerid     = shift;
    my $recipe_key  = shift;
    my $name        = shift;
    my $min_time    = shift;
    my $max_time    = shift;
    my $init_time   = shift;
    my $init_rand   = shift;
    my $min_votes   = shift;
    my $vote_times  = shift;
    my $cooldown    = shift;
    my $time_past   = shift;
    my $time_left   = shift;
    my $msg_times   = shift;
    my $safeword    = shift;

    my $sql = qq| update recipes set name = ?, min_time = ?, max_time = ?,
                init_time = ?, init_rand = ?, min_votes = ?, vote_times = ?,
                vote_cooldown = ?, time_past = ?, time_left = ?,
                msg_times = ?, safeword = ?
                where recipe_key = ? and ownerid = ? |;
    my $dbh = db_connect();
    my $sth = $dbh->prepare($sql);
    my $rv = $sth->execute($name, $min_time, $max_time, $init_time, $init_rand,
                    $min_votes, $vote_times, $cooldown, $time_past, $time_left,
                    $msg_times, $safeword, $recipe_key, $ownerid);
    if ($rv > 0) {
        return 1;
    }
    return;
}

sub update_session {
    # Update the settings of a recipe
    my $trusteeid   = shift;
    my $session_key = shift;
    my $min_time    = shift;
    my $max_time    = shift;
    my $min_votes   = shift;
    my $vote_times  = shift;
    my $cooldown    = shift;
    my $time_past   = shift;
    my $time_left   = shift;
    my $msg_times   = shift;
    my $safeword    = shift;

    my $sql = qq| update sessions set min_time = ?, max_time = ?,
                min_votes = ?, vote_times = ?, vote_cooldown = ?, time_past = ?,
                time_left = ?, msg_times = ?, safeword = ?
                where session_key = ? and trusteeid = ? |;
    my $dbh = db_connect();
    my $sth = $dbh->prepare($sql);
    my $rv = $sth->execute($min_time, $max_time, $min_votes,
                    $vote_times, $cooldown, $time_past, $time_left, $msg_times,
                    $safeword, $session_key, $trusteeid);
    if ($rv > 0) {
        return 1;
    }
    return;
}

sub start_session {
    # Create a new session based off a provided recipe
    my $userid  = shift;
    my $recipe  = shift;

    my $time    = time;

    my $end_time = $$recipe{init_time} + $time;
    my $rand_time = int(rand($$recipe{init_time} / 2));
    if ($$recipe{init_rand} == 1) {
        $end_time = ($rand_time * 2) + $time;
    } elsif ($$recipe{init_rand} == 2) {
        # Low End
        $end_time = ($rand_time - int($$recipe{init_time} / 2)) + $time;
    } elsif ($$recipe{init_rand} == 3) {
        # High End
        $end_time = ($rand_time + int($$recipe{init_time} / 2)) + $time;
    }

    my $session_key = make_key('sessions','session_key');

    my $sql = qq| insert into sessions (session_key,trusteeid,waiterid,
                start_time,end_time,min_time,max_time,min_votes,vote_times,
                vote_cooldown,time_past,time_left,msg_times,safeword) values
                (?,?,?,?,?,?,?,?,?,?,?,?,?,?) |;
    my $dbh = db_connect();
    my $sth = $dbh->prepare($sql);
    my $rv = $sth->execute($session_key, $$recipe{ownerid}, $userid, $time,
                    $end_time, $$recipe{min_time}, $$recipe{max_time},
                    $$recipe{min_votes}, $$recipe{vote_times},
                    $$recipe{vote_cooldown}, $$recipe{time_past},
                    $$recipe{time_left}, $$recipe{msg_times},
                    $$recipe{safeword});
    if ($rv > 0) {
        return 1;
    }
    return;
}

sub make_recipe {
    # Create a waiting recipe
    my $ownerid     = shift;
    my $name        = shift;
    my $min_time    = shift;
    my $max_time    = shift;
    my $init_time   = shift;
    my $init_rand   = shift;
    my $min_votes   = shift;
    my $vote_times  = shift;
    my $time_past   = shift;
    my $time_left   = shift;

    my $recipe_key = make_key('recipes','recipe_key');

    my $dbh = db_connect();
    my $sql = qq| insert into recipes (ownerid, recipe_key, name,
                    min_time, max_time, init_time, init_rand,
                    min_votes, vote_times, time_past, time_left)
                    values (?,?,?,?,?,?,?,?,?,?,?) |;
    my $sth = $dbh->prepare($sql);
    my $rv = $sth->execute($ownerid, $recipe_key, $name, $min_time, $max_time,
                    $init_time, $init_rand, $min_votes, $vote_times, $time_past,
                    $time_left);
    $sth->finish();
    $dbh->disconnect();

    # Return 1 if the insert / create was a success
    return 1 if ($rv > 0);
    return;
}

sub update_end_time {
    # Adjust the remaining time of a session
    my $sessionid   = shift;
    my $adjustment  = shift;

    my $sql = qq| update sessions set end_time = end_time + ?
                        where sessionid = ? |;
    my $dbh = db_connect();
    my $sth = $dbh->prepare($sql);
    my $rv = $sth->execute($adjustment,$sessionid);
    $sth->finish();
    $dbh->disconnect();

    # Return 1 if the time warp was successful
    return 1 if ($rv > 0);
    return;
}

sub cast_vote {
    my $sessionid   = shift;
    my $ip          = shift;
    my $adjustment  = shift;
    my $name        = shift;

    if (update_end_time($sessionid,$adjustment)) {
        my $sql = qq| insert into votes (sessionid,ip,time,vote,voter_name)
                    values (?, ?, ?, ?, ?) |;
        my $dbh = db_connect();
        my $sth = $dbh->prepare($sql);
        my $rv = $sth->execute($sessionid,$ip,time,$adjustment,$name);
        $sth->finish();
        $dbh->disconnect();
        if ($rv > 0) {
            return 1;
        }
    }
    return;
}

sub get_end_time {
    # Return the end time for a selected session
    my $sessionid   = shift;

    my $dbh = db_connect();
    my $sql = qq| select start_time,end_time,max_time from sessions
                    where sessionid = ? |;
    my $sth = $dbh->prepare($sql);
    $sth->execute($sessionid);
    my ($start_time,$end_time,$max_time) = $sth->fetchrow_array();
    $sth->finish();
    $dbh->disconnect();

    my $maximum = $start_time + $max_time;
    if ($end_time > $maximum) {
        $end_time = $maximum;
    }
    if ($end_time > 0) {
        return $end_time;
    }
    return 0;
}

sub convert_from_seconds {
    # Convert seconds to weeks, days, hours, minutes, seconds
    my $time = shift;

    $time = abs($time);
    # Bail if $time is anything but digits
    return if ($time =~ /[^0-9]/);
    my ($days,$hours,$minutes,$seconds) = (gmtime($time))[7,2,1,0];
    my $weeks = int($days / 7);
    $days = $days - ($weeks * 7);
    return ($weeks,$days,$hours,$minutes,$seconds);
}

sub convert_to_seconds {
    # Convert weeks/days/hours to seconds
    my $weeks   = shift;
    my $days    = shift;
    my $hours   = shift;

    my $seconds = ($weeks * 7 * 24 * 60 * 60) +
                  ($days * 24 * 60 * 60) +
                  ($hours * 60 * 60);
    return $seconds;
}

sub human_time {
    my $time    = shift;

    my $output = '';
    my ($weeks,$days,$hours,$minutes,$seconds) = convert_from_seconds($time);
    if ($weeks > 0) {
        $output = sprintf("%d %s, %d %s, %d %s, %d %s and %d %s",
        $weeks, ($weeks == 1)?"week":"weeks",
        $days, ($days == 1)?"day":"days",
        $hours, ($hours == 1)?"hour":"hours",
        $minutes, ($minutes==1)?"minute":"minutes",
        $seconds, ($seconds==1)?"second":"seconds");
    } elsif ($days > 0) {
        $output = sprintf("%d %s, %d %s, %d %s and %d %s",
        $days, ($days == 1)?"day":"days",
        $hours, ($hours == 1)?"hour":"hours",
        $minutes, ($minutes==1)?"minute":"minutes",
        $seconds, ($seconds==1)?"second":"seconds");
    } elsif ($hours > 0) {
        $output = sprintf("%d %s, %d %s and %d %s",
        $hours, ($hours == 1)?"hour":"hours",
        $minutes, ($minutes==1)?"minute":"minutes",
        $seconds, ($seconds==1)?"second":"seconds");
    } elsif ($minutes > 0) {
        $output = sprintf("%d %s and %d %s",
        $minutes, ($minutes==1)?"minute":"minutes",
        $seconds, ($seconds==1)?"second":"seconds");
    } else {
        $output = sprintf("%d %s",
        $seconds, ($seconds==1)?"second":"seconds");
    }

    if ($time < 0) {
        $output = "-$output";
    }
    return $output;
}

sub fuzzy_time {
    my $seconds = shift;
    my $unit    = shift;
    my $range   = shift;
    my $max     = shift;
    my $type    = shift;

    my $single = $type;
    $single =~ s/s$//;

    my $text = '';
    for my $i (1 .. $max) {
        if ($seconds > ($i * $unit + $range)) {
            $text = sprintf('more than %d %s',$i,($i==1)?$single:$type);
        } elsif ($seconds > ($i * $unit - $range) and
                 $seconds < ($i * $unit + $range)) {
            $text = sprintf('about %d %s',$i,($i==1)?$single:$type);
        }
    }
    return $text;
}

sub approx_time {
    my $seconds = shift;

    my $output = '';
    my $year    = 365 * 24 * 60 * 60;
    my $month   =  30 * 24 * 60 * 60;
    my $week    =   7 * 24 * 60 * 60;
    my $day     =       24 * 60 * 60;
    my $hour    =            60 * 60;

    if ($seconds > ($year - $month)) {
        $output = fuzzy_time($seconds,$year,$month,10,'years');
    } elsif ($seconds > ($month - $day * 5)) {
        $output = fuzzy_time($seconds,$month,$day * 5,12,'months');
    } elsif ($seconds > ($week - $day * 2)) {
        $output = fuzzy_time($seconds,$week,$day * 2,4,'weeks');
    } elsif ($seconds > ($day - $hour * 4)) {
        $output = fuzzy_time($seconds,$day,$hour * 4,7,'days');
    } elsif ($seconds > ($hour - 15 * 60)) {
        $output = fuzzy_time($seconds,$hour,15 * 60,24,'hours');
    } else {
        $output = fuzzy_time($seconds,60,15,60,'minutes');
    }

    return $output;
}

sub time_remaining {
    # Return time left on a session's clock in a format like:
    # 1 week, 4 days, 10 hours, 3 minutes and 43 seconds
    my $session = shift;

    my $end_time = get_end_time($session);
    my $seconds = $end_time - time;
    if ($seconds > 0) {
        my ($weeks,$days,$hours,$minutes,$seconds) =
            convert_from_seconds($seconds);

        my $output = '';
        if ($weeks > 0) {
            $output = sprintf("%d %s, %d %s, %d %s, %d %s and %d %s",
            $weeks, ($weeks == 1)?"week":"weeks",
            $days, ($days == 1)?"day":"days",
            $hours, ($hours == 1)?"hour":"hours",
            $minutes, ($minutes==1)?"minute":"minutes",
            $seconds, ($seconds==1)?"second":"seconds");
            return $output;
        }
        if ($days > 0) {
            $output = sprintf("%d %s, %d %s, %d %s and %d %s",
            $days, ($days == 1)?"day":"days",
            $hours, ($hours == 1)?"hour":"hours",
            $minutes, ($minutes==1)?"minute":"minutes",
            $seconds, ($seconds==1)?"second":"seconds");
            return $output;
        }
        if ($hours > 0) {
            $output = sprintf("%d %s, %d %s and %d %s",
            $hours, ($hours == 1)?"hour":"hours",
            $minutes, ($minutes==1)?"minute":"minutes",
            $seconds, ($seconds==1)?"second":"seconds");
            return $output;
        }
        if ($minutes > 0) {
            $output = sprintf("%d %s and %d %s",
            $minutes, ($minutes==1)?"minute":"minutes",
            $seconds, ($seconds==1)?"second":"seconds");
            return $output;
        }
        $output = sprintf("%d %s", $seconds, ($seconds==1)?"second":"seconds");
        return $output;
    }
    return 0;
}

sub make_key {
    # Generate a random / unique alphanumeric key for sharing
    my $table   = shift;
    my $keyname = shift;

    my @alphabet = ('A'..'Z', 'a'..'z', 0..9);

    my $sql = qq| select $keyname from $table where $keyname = ? |;
    my $dbh = db_connect();
    my $sth = $dbh->prepare($sql);

    my $key = '';
    while ($key eq '') {
        for (1..16) {
            $key .= $alphabet[rand(@alphabet)];
        }
        $sth->execute($key);
        my ($used) = $sth->fetchrow_array();
        if ($used) {
            $key = '';
        }
    }
    $sth->finish();
    $dbh->disconnect();
    return $key;
}

1;
__END__
