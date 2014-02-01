#!/usr/bin/perl

use strict;
use warnings;

use WaiterWWW;

my $session = Waiter::WWW::load_session('Waiter');
Waiter::WWW::logout($session);

exit;
