#!/usr/bin/perl

use strict;
use warnings;

use Waiter;
use WaiterWWW;

my $session = Waiter::WWW::load_session('Waiter');
my $data = Waiter::WWW::read_params($session);

if (Waiter::auth_user($$data{username},$$data{hash})) {
    my $info = '';
    if ($$data{begin} and $$data{recipe_key} and $$data{recipe_key} ne '') {
        my $userid = Waiter::get_userid($$data{username});
        if (Waiter::get_sessionid_active($userid)) {
            $info = 'You are already waiting.';
        } else {
            if (my $recipe = Waiter::get_recipe_by_key($$data{recipe_key})) {
                if (Waiter::start_session($userid,$recipe)) {
                    $info = "Begin Waiting using Recipe: $$data{recipe_key}";
                } else {
                    $info = 'Failed to start session!';
                }
            } else {
                $info = "Recipe: $$data{recipe_key} not found.";
            }
        }
    }
    home_page($data,$info);
} else {
    # Non authenticated session, send to login page.
    print $session->header(
        -location   => 'index.pl'
    );
}

exit;

sub home_page {
    # The main page
    my $data    = shift;
    my $error   = shift || '';

    my $status = qq|
    <p>Welcome $$data{username}!</p>
|;

    my $userid = Waiter::get_userid($$data{username});
    my $sessionid = Waiter::get_sessionid_active($userid);
    if ($sessionid) {
        $status .= Waiter::WWW::session_status($sessionid);
    } else {
        $status .= qq|
    <p>Enter a Recipe Key to Begin Waiting!</p>
    <form method='post'>
    <table class='options'>
      </tr>
        <td><input type='text' name='recipe_key'></td>
        <td><input type='submit' name='begin' value='Begin Waiting'></td>
      </tr>
    </table>
    </form>
|;
    }
    my $messages = Waiter::WWW::messages_html($data);

    Waiter::WWW::page_header('The Waiting Game',1);

    print qq|
    $status
    $messages
|;
    Waiter::WWW::page_footer($error);
}
