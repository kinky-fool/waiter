#!/usr/bin/perl

use strict;
use warnings;

use Waiter;
use WaiterWWW;

my $session = Waiter::WWW::load_session('Waiter');
my $data = Waiter::WWW::read_params($session);

if (Waiter::auth_user($$data{username},$$data{hash})) {
    my $userid = Waiter::get_userid($$data{username});
    if ($$data{recipe} and ($$data{recipe} ne '')) {
        $$data{recipe_key} = $$data{recipe};
        if ($$data{recipe} eq 'new') {
            my $recipe_key = Waiter::create_new_recipe($userid);
            if ($recipe_key) {
                print $session->header(
                    -location   => "recipes.pl?recipe=$recipe_key"
                );
            } else {
                recipe_list_page('Failed to create recipe.');
            }
        } else {
            if (Waiter::is_recipe_owner($userid,$$data{recipe_key})) {
                recipe_modify_page($$data{recipe_key});
            } else {
                recipe_list_page('You cannot view that recipe.');
            }
        }
    } elsif ($$data{save}) {
        my @options = Waiter::WWW::prepare_recipe($data);
        if (Waiter::update_recipe(@options)) {
            recipe_list_page("Recipe $$data{recipe_key} saved successfully.");
        } else {
            recipe_list_page("Recipe save failed.");
        }
    } elsif ($$data{rm}) {
        if (Waiter::is_recipe_owner($userid,$$data{recipe_key})) {
            if (Waiter::delete_recipe($$data{recipe_key})) {
                recipe_list_page("Recipe $$data{recipe_key} deleted");
            } else {
                recipe_list_page("Failed to delete recipe: Unknown Error");
            }
        } else {
            recipe_list_page('That is not your recipe to delete');
        }
    } else {
        recipe_list_page();
    }
} else {
    # Non authenticated session, send to login page.
    print $session->header(
        -location   => 'index.pl'
    );
}

exit;

sub recipe_modify_page {
    # Page for modifying a recipe.
    my $recipe_key  = shift;

    my $recipe = Waiter::get_recipe_by_key($recipe_key);
    my $details = "Editing Recipe '$recipe_key'";

    my %checked = ();
    foreach my $time (split(/:/,$$recipe{vote_times})) {
        $checked{"time_$time"} = 'checked';
    }
    # Create the drop down selectors for setting wait duration
    my $min_list = Waiter::WWW::time_dropdown(
        'min','Minimum Wait Time',$$recipe{min_time}
    );
    my $max_list = Waiter::WWW::time_dropdown(
        'max','Maximum Wait Time',$$recipe{max_time}
    );
    my $init_list = Waiter::WWW::time_dropdown(
        'init','Initial Wait Time',$$recipe{init_time}
    );
    # Create the checkboxes for voting options
    my $time_checkboxes = Waiter::WWW::time_checkboxes($$recipe{vote_times});
    my $vote_options = Waiter::WWW::vote_options(
        $$recipe{min_votes},$$recipe{vote_cooldown},$$recipe{msg_times}
    );

    my $init_rand_options = Waiter::WWW::radio_options(
        'init_rand',$$recipe{init_rand},
        "Don't Randomize Initial Time:ir:0",
        "Random Initial Time (0 to Initial Time):ir:1",
        "Random Initial Time; Low End:ir:2",
        "Random Initial Time; High End:ir:3"
    );
    my $time_past_options = Waiter::WWW::radio_options(
        'time_past', $$recipe{time_past},
        "Show Time Spent Waiting:tp:1",
        "Show Approximate Time Spent Waiting:tp:2",
        "Hide Time Spent Waiting:tp:0"
    );
    my $time_left_options = Waiter::WWW::radio_options(
        'time_left', $$recipe{time_left},
        "Show Time Remaining:tl:1",
        "Show Approximate Time Remaining:tl:2",
        "Hide Time Remaining:tl:0"
    );


    Waiter::WWW::page_header($details,1);
    print qq|
    <form method='post'>
      <table class='options'>
        <tr valign='center'>
          <td align='right'>Recipe Name:</td>
          <td align='left'>
            <input type='text' name='name' value='$$recipe{name}'>
          </td>
        </tr>
      </table>
      <hr/>
      <table class='options'>
        $init_list
        $min_list
        $max_list
      </table>
      <hr/>
      <table class='options'>
        <caption>Voting Time Options</caption>
        $time_checkboxes
      </table>
      <table class='options'>
        $vote_options
      </table>
      <hr/>
      <table class='options'>
        $init_rand_options
      </table>
      <hr/>
      <table class='options'>
        $time_past_options
      </table>
      <hr/>
      <table class='options'>
        $time_left_options
      </table>
      <hr/>
      <table class='options'>
        <tr valign='center'>
          <td align='left'>
            Safeword:
          </td>
          <td align='right'>
            <input type='text' name='safeword' value='$$recipe{safeword}'>
          </td>
        </tr>
        <tr valign='center'>
          <td align='left'>
            <input type='submit' name='rm' value='Delete'>
          </td>
          <td align='right'>
            <input type='submit' name='save' value='Save'>
            <input type='hidden' name='recipe_key' value='$recipe_key'>
          </td>
        </tr>
      </table>
    </form>
|;
    Waiter::WWW::page_footer();
}

sub recipe_list_page {
    my $error = shift || '';

    my $userid = Waiter::get_userid($$data{username});
    my @recipes = Waiter::get_user_recipes($userid);
    my $html = '';
    foreach my $key (@recipes) {
        my $recipe = Waiter::get_recipe_by_key($key);
        my $name = $key;
        if ($$recipe{name}) {
            $name = $$recipe{name};
        }
        $html .= qq|
    <tr valign='center'>
      <td align='left'>$key</td>
      <td align='left'>$name</td>
      <td align='right'><a href='recipes.pl?recipe=$key'>Modify</a>
    </tr>
|;
    }
    if ($html eq '') {
        $html = qq|
    <tr valign='top'>
      <td>No Recipes Found</td>
      <td>&nbsp;</td>
      <td>&nbsp;</td>
    </tr>
|;
    } else {
        $html = qq|
    <tr valign='center'>
      <td align='left'>Recipe Key</td>
      <td align='left'>Recipe Name</td>
      <td>&nbsp;</td>
    </tr>
    $html
|;
    }

    Waiter::WWW::page_header('Your Recipes',1);
    print qq|
    <h3><a href='recipes.pl?recipe=new'>Create a New Recipe</a></h3>
    <table class='options'>
    $html
    </table>
    <br/>
    <br/>
|;
    Waiter::WWW::page_footer($error);
}
