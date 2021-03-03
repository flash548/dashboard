#! perl6
use lib <.>;
use Term::Dashboard;

my $dash = Term::Dashboard::Dashboard.new;
my $win1 = $dash.create-window(
                    x => 0,
                    y => 0,
                    width => '50%',
                    height => '50%',
                    bg => 'black',
                    fg => 'red',
                    fill-char => ' ',
                    name => 'Win1',
                    );

my $win2 = $dash.create-window(
                    x => 0,
                    y => '50%',
                    width => '50%',
                    height => '50%',
                    bg => 'black',
                    fg => 'blue',
                    fill-char => ' ',
                    name => 'Win2',
                    );

my $win3 = $dash.create-window(
                    x => '50%',
                    y => '0%',
                    width => '50%',
                    height => '50%',
                    bg => 'black',
                    fg => 'blue',
                    fill-char => ' ',
                    name => 'Win3',
                    );



my $win4 = $dash.create-window(
                    x => '50%',
                    y => '50%',
                    width => '50%',
                    height => '50%',
                    bg => 'black',
                    fg => 'blue',
                    fill-char => '.',
                    name => 'Win4',
                    );

$dash.add-window($win1, $win2, $win3, $win4);

start {

    for ^20 {
        $win1.write(DateTime.now ~ "\n");
        sleep 0.3;
    }

    $win1.clear;

}

start {

    for ^20 {
        $win2.write(DateTime.now ~ "\n");
        sleep 0.5;
    }

    $win1.clear;

}

start {

    for ^20 {
        $win3.write(DateTime.now ~ "\n");
        sleep 0.2;
    }

}

start {

    for ^20 {
        $win4.write(DateTime.now ~ "\n");
        sleep 0.3;
    }


}

$dash.run;

END {
    #$dash.cleanup;
}