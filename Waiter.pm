#!/usr/bin/perl

use strict;
use warnings;

use DBI;

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

    my $sql = qq{ select password from members where username = ? };
    my $dbh = db_connect();
    my $sth = $dbh->prepare($sql);
    $sth->execute($user);
    my ($hash) = $sth->fetchrow_array();
    $sth->finish();
    $dbh->disconnect();
    if ($hash and $hash ne '') {
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

sub make_user {
    # Create / store user information in the database
    my $user    = shift;
    my $pass    = shift;

    my $dbh = db_connect();
    my $userq = $dbh->quote("$user");
    my $select = qq{ select userid from users where username = $userq };
    my ($uid) = $dbh->selectrow_array($select);
    if ($uid) {
        logger("Account creation failed: '$user' already exists");
        $dbh->disconnect;
        return;
    }
    my $salt = join '',('.','.',0..9,'A'..'Z','a'..'z')[rand 64, rand 64];
    my $crypt = crypt($pass,$salt);
    my $cryptq = $dbh->quote($crypt);
    my $insert = qq{ insert into users (username,password)
                        values ($userq,$cryptq) };
    my $rv = $dbh->do($insert);
    $dbh->disconnect;
    if ($rv) {
        logger("Account creation success: '$user' created");
        return 1;
    }
    logger("Account creation failed: '$user' DB insert failed");
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

    my $sql = qq{ select end_time from sessions where sessionid = ? };
    my $dbh = db_connect();
    my $sth = $dbh->prepare($sql);
    $sth->execute($sessionid);
    my ($time) = $sth->fetchrow_array();
    if ($time > 0) {
        return $time;
    }
    return;
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
