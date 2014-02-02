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

    my $sql = qq{ select password from users where username = ? };
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
    if ($hash and ($hash eq $correct)) {
        return 1;
    }

    logger("Login failed for '$user'; invalid password");
    return;
}

sub get_userid {
    # Return a user's userid using a username
    my $user    = shift;

    my $sql = qq{ select userid from users where username = ? };
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

sub is_waiting {
    # Return sessionid if a user is currently in a session
    my $userid  = shift;

    my $sql = qq{ select sessionid from sessions where
                        finished = 0 and wearerid = ? };
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

sub get_recipe_by_key {
    # Return a hashref of the recipe settings, if found
    my $recipe_key  = shift;

    my $sql = qq{ select * from recipes where recipe_key = ? };
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

sub make_user {
    # Create / store user information in the database
    my $user    = shift;
    my $pass    = shift;

    my $sql = qq { select userid from users where username = ? };
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

    $sql = qq{ insert into users (username,password) values (?, ?) };
    $sth = $dbh->prepare($sql);
    my $rv = $sth->execute($user,$hash);
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

    my $sql = qq{ select ownerid from recipes where recipe_key = ? };
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

sub make_recipe {
    # Create a waiting recipe
    my $ownerid     = shift;
    my $name        = shift;
    my $min_time    = shift;
    my $max_time    = shift;
    my $start_time  = shift;
    my $start_rand  = shift;
    my $min_votes   = shift;
    my $vote_times  = shift;
    my $time_past   = shift;
    my $time_left   = shift;

    my $recipe_key = make_key('recipes','recipe_key');

    my $dbh = db_connect();
    my $sql = qq{ insert into recipes (ownerid, recipe_key, name,
                    min_time, max_time, start_time, start_rand,
                    min_votes, vote_times, time_past, time_left)
                    values (?,?,?,?,?,?,?,?,?,?,?) };
    my $sth = $dbh->prepare($sql);
    my $rv = $sth->execute($ownerid, $recipe_key, $name,
                    $min_time, $max_time, $start_time, $start_rand,
                    $min_votes, $vote_times, $time_past, $time_left);
    $sth->finish();
    $dbh->disconnect();

    # Return 1 if the insert / create was a success
    return 1 if ($rv > 0);
    return;
}

sub alter_time {
    # Adjust the remaining time of a session
    my $sessionid   = shift;
    my $adjustment  = shift;

    my $sql = qq{ update sessions set end_time = end_time + ?
                        where sessionid = ? };
    my $dbh = db_connect();
    my $sth = $dbh->prepare($sql);
    my $rv = $sth->execute($adjustment, $sessionid);
    $sth->finish();
    $dbh->disconnect();

    # Return 1 if the time warp was successful
    return 1 if ($rv > 0);
    return;
}

sub get_end_time {
    # Return the end time for a selected session
    my $sessionid   = shift;

    my $dbh = db_connect();
    my $sql = qq{ select start_time,end_time,recipeid from sessions
                    where sessionid = ? };
    my $sth = $dbh->prepare($sql);
    $sth->execute($sessionid);
    my ($start_time,$end_time,$recipeid) = $sth->fetchrow_array();
    $sth->finish();

    $sql = qq{ select max_time from recipes where recipeid = ? };
    $sth = $dbh->prepare($sql);
    $sth->execute($recipeid);
    my ($max_time) = $sth->fetchrow_array();
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

sub convert_seconds {
    # Convert seconds to weeks, days, hours, minutes, seconds
    my $seconds = shift;

    if ($seconds > 0) {
        my ($days,$hours,$minutes,$seconds) = (gmtime($seconds))[7,2,1,0];
        my $weeks = int($days / 7);
        $days = $days - ($weeks * 7);
        return ($weeks,$days,$hours,$minutes,$seconds);
    }
    return;
}

sub time_remaining {
    # Return time left on a session's clock in a format like:
    # 1 week, 4 days, 10 hours, 3 minutes and 43 seconds
    my $session = shift;

    my $end_time = get_end_time($session);
    my $seconds = $end_time - time;
    if ($seconds > 0) {
        my ($weeks,$days,$hours,$minutes,$seconds) = convert_seconds($seconds);

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

    my $sql = qq{ select $keyname from $table where $keyname = ? };
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
