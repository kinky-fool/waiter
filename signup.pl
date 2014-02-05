#!/usr/bin/perl

use strict;
use warnings;

use Waiter;
use WaiterWWW;

my $session = Waiter::WWW::load_session('Waiter');
my $data = Waiter::WWW::read_params($session);

if ($$data{action} and ($$data{action} eq 'create')) {
    if ($$data{pass0} and $$data{pass1} and $$data{username}) {
        if ($$data{pass0} eq $$data{pass1}) {
            if (Waiter::make_user($$data{username},$$data{pass0})) {
                $$data{hash} = Waiter::make_hash(
                                $$data{username},$$data{pass0});
                delete $$data{pass0};
                delete $$data{pass1};
                Waiter::WWW::save_session($session,$data);
                Waiter::WWW::login($session);
            } else {
                sign_up_page('',"Failed to create user $$data{username}.");
            }
        } else {
            sign_up_page($$data{username},'Passwords do not match.');
        }
    } else {
        sign_up_page('','Please fill in all the fields.');
    }
} else {
    sign_up_page('','');
}

Waiter::WWW::save_session($session,$data);
exit;

sub sign_up_page {
    my $user    = shift || '';
    my $error   = shift || '';

    Waiter::WWW::page_header('Sign Up to Wait!',0);
    print qq|
    <form method='post'>
      <table id='sign_up'>
        <tr>
          <td>username:</td>
          <td>
            <input type='text' name='username' size='15' value='$user'/>
          </td>
        </tr><tr>
          <td>password:</td>
          <td>
            <input type='password' name='pass0' size='15' />
          </td>
        </tr><tr>
          <td>password again:</td>
          <td>
            <input type='password' name='pass1' size='15' />
          </td>
        </tr>
      </table>
      <br/>
      <input type='submit' name='action' value='create' />
    </form>
|;
    Waiter::WWW::page_footer($error);
}
