#!/usr/bin/perl

use strict;
use warnings;

use Waiter;
use WaiterWWW;

my $session = Waiter::WWW::load_session('Waiter');
my $data = Waiter::WWW::read_params($session);

if ($$data{authenticated}) {
    if ($$data{update}) {

    } else {
        settings_page($data);
    }
} else {
    # Non authenticated session, send to login page.
    print $session->header(
        -location   => 'index.pl'
    );
}

exit;

sub settings_page {
    my $data    = shift;
    my $error   = shift || '';

    my $user = Waiter::get_user_by_username($$data{username});

    my $d_name = Waiter::get_display_name($$user{userid});
    my $mt_checked = '';
    $mt_checked = ' checked' if ($$user{msg_times} = 1);

    Waiter::WWW::page_header('The Waiting Game',1);
    print qq|
    <form method='post'>
      <table class='options'>
        <tr>
          <td align='left'>Username:</td>
          <td align='center'>$$data{username}</td>
        </tr>
        <tr>
          <td align='left'>Display Name:</td>
          <td align='right'>
            <input type='text' name='d_name' size=15 value='$d_name'/>
          </td>
        </tr>
        <tr>
          <td align='left'>Old Password:</td>
          <td align='right'>
            <input type='password' name='oldpass' size=15 />
          </td>
        </tr>
        <tr>
          <td align='left'>New Password:</td>
          <td align='right'>
            <input type='password' name='newpass0' size=15 />
          </td>
        </tr>
        <tr>
          <td align='left'>New Password, again:</td>
          <td align='right'>
            <input type='password' name='newpass1' size=15 />
          </td>
        </tr>
        <tr>
          <td align='left'>Display Time in Messages?</td>
          <td align='right'>
            <input type='checkbox' name='msg_times'$mt_checked />
          </td>
        </tr>
      </table>
      <br/>
      <input type='submit' name='update' value='Update' />
    </form>
|;
    Waiter::WWW::page_footer($error);
}
