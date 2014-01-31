#!/usr/bin/perl

use strict;
use warnings;

use DBI;

package Waiter;

my $db_user = 'waiter';
my $db_pass = 'patience';
my $db_name = 'waiting-game';
my $db_host = 'localhost';

sub db_connect {
    my $dsn = "dbi:mysql:database=$db_name;host=$db_host";
    my $dbh = DBI->connect($dsn,$db_user,$db_pass,{ RaiseError => 1 })
                or die "Failed to connect to database: $DBI::errstr";
    return $dbh;
}

sub auth_user {
    # Authenticate a user login
    my $user    = shift;
    my $pass    = shift;

    my $dbh = db_connect();
    my $userq = $dbh->quote("$user");
    my $select = qq{ select password from users where username = $userq };
    my ($hash) = $dbh->selectrow_array($select);
    $dbh->disconnect;
    if ($hash and ($hash ne '')) {
        if (crypt($pass,$hash) eq $hash) {
            return 1;
        } else {
            logger("Login failed for '$user'; invalid password");
            return;
        }
    }
    logger("Login failed for '$user'; unknown user");
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
    while ($key -eq '') {
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
