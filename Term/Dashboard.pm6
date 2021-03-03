unit module Term::Dashboard;
use Terminal::ANSIColor;
use Term::TransKey;

my $lock = Lock::Async.new;

class Screen {

    has ($.rows, $.cols);
    has Int ($.width, $.height);
    has $.bg = 'black';
    has $.fg = 'white';
    has $.fill-char = ' ';
    has @.windows = ();
    has $.active-window;
    has $.active-window-idx;
    has $.focused-color = 'cyan';

    method TWEAK  {
        signal(SIGWINCH).tap( { self.resize; } );
        self.resize;
    }
    method resize {
        ($!rows, $!cols) = qx/stty size/.split("\n")[0].split(/\s/)>>.Int;
        self.init;
    }
    method init {
        $!width = $!cols;
        $!height = $!rows;
        self.hide-cursor;
        self.cls;
        self.redraw-windows;
    }
    method redraw-windows {
        for @!windows -> $win {
            $win.draw();
        }
    }
    method pos-cursor(Int $x, Int $y) {
        sprintf "\o33[%d;%dH", $y + 1, $x + 1;
    }
    method go-to-xy (Int $x, Int $y) {
        $lock.protect({
            print(self.pos-cursor($x, $y) ~ '');
        });
    }
    method write-xy (Int $x, Int $y, $text, :$fore='white', :$back='black') {
        $lock.protect({
            my $cmd = self.pos-cursor($x, $y);
            $cmd ~= color($fore);
            $cmd ~= color("on_" ~ $back);
            $cmd ~= $text;
            $cmd ~= color('reset');
            print $cmd;
        });
    }

    #| Fills a part of the screen with an optional fill-character of fore/back color
    method fill(:$x, :$y, :$width, :$height, :$char=$!fill-char, :$fore=$!fg, :$back=$!bg) {
        for $y ..^ ($y+$height) -> $ypos {
            self.write-xy($x, $ypos, $char x $width, fore => $fore, back => $back);
        }
    }
    method cls(:$char=$!fill-char, :$fore=$!fg, :$back=$!bg) {
        self.fill(x => 0,
                    y => 0,
                    width => $!width,
                    height => $!height,
                    char => $char,
                    fore => $fore,
                    back => $back);
    }
    method hide-cursor {
        print "\e[?25l";
    }
    method show-cursor {
        print "\e[0H\e[0J\e[?25h";
    }
    method add-window(*@windows) {
        for @windows -> $win {
            @!windows.push($win);
            $win.draw();
        }

        $!active-window-idx = @!windows.elems-1;
        self.focus-active-window;
    }
    method focus-active-window {
        for @!windows -> $win {
            $win.set-focused(False);
            $win.draw();
        }

        $!active-window = @!windows[$!active-window-idx];
        $!active-window.set-focused(True);
        $!active-window.draw;
    }
    method move-window-focus($direction) {
        if ($direction eq "left") {
            if ($!active-window-idx - 1 < 0) {
                $!active-window-idx = @!windows.elems-1;
            }
            else {
                $!active-window-idx--;
            }
        }
        elsif ($direction eq "right") {
            if ($!active-window-idx+1 > @!windows.elems-1) {
                $!active-window-idx = 0;
            }
            else {
                $!active-window-idx++;
            }
        }

        self.focus-active-window;
    }

    method dispatch-key($key) {
        if ($key eq "<LEFT>") {
            self.move-window-focus("left");
        }
        elsif ($key eq "<RIGHT>") {
            self.move-window-focus("right");
        }
        else {
            # pass it off to the active window
            $!active-window.process-key($key) if defined($!active-window);
        }
    }
}

class Window {

    has Screen $.scr = Nil;
    has $.x = 0;
    has $.y = 0;
    has $.width = 0;
    has $.height = 0;
    has $!xpos;
    has $!ypos;
    has Str $.bg = 'black';
    has Str $.fg = 'white';
    has Str $.fill-char = ' ';
    has Str $.buffer = "";
    has Str $.name;
    has $.focused = False;

    method TWEAK {
        self.init-size;
    }

    method init-size() {
        if $!x.ends-with("%") {
            # treat as percent
            $!x = (($!x.match(/\d+/) / 100) * $!scr.width).Int;
        }
        if $!y.ends-with("%") {
            # treat as percent
            $!y = (($!y.match(/\d+/) / 100) * $!scr.height).Int;
        }
        if $!width.ends-with("%") {
            # treat as percent
            $!width = (($!width.match(/\d+/) / 100) * $!scr.width).Int;
        }
        if $!height.ends-with("%") {
            # treat as percent
            $!height = (($!height.match(/\d+/) / 100) * $!scr.height).Int;
        }

        $!xpos = $!x + 1;
        $!ypos = $!y + 1;
    }

    method set-focused($focused) {
        $!focused = $focused;
    }

    #| Draws the window border and clears it and re-renders its contents
    method draw() { 
        self.init-size;

        my $border-color = do {
            if ($!focused) {
                $!scr.focused-color;
            }
            else {
                $!fg;
            }
        };

        $!scr.write-xy($!x, $!y, "\x[256D]" ~ ('-' x $!width - 2) ~ "\x[256E]", fore => $border-color, back => $!bg);
        $!scr.write-xy($!x, $!y+1, "\x[2502]" ~ color('black') ~ color("on_$!fg") ~ $!name ~ (' ' x $!width - $!name.chars - 2) ~ color('reset') ~ "\x[2502]");
        my $tmp-y = $!y+2;
        for ^($!height - 3) {
            $!scr.write-xy($!x, $tmp-y, "\x[2502]", fore => $border-color, back => $!bg);
            $!scr.write-xy($!x + ($!width - 1), $tmp-y, "\x[2502]", fore => $border-color, back => $!bg);
            $tmp-y++;
        }
        $!scr.write-xy($!x, $!y + ($!height - 1), "\x[2570]" ~ ('-' x $!width - 2) ~ "\x[256F]", fore => $border-color, back => $!bg);
        self.reset-cursor;
        self.render-text;
    }

    method reset-cursor {
        $!xpos = $!x + 1;
        $!ypos = $!y + 2;
    }

    method scroll-up() { ... }

    method write($text) { 
        $!buffer ~= $text;
        self.render-text;        
    }

    method process-key($key) {
        self.write("$key\n");
    }

    method render-text {
        self.reset-cursor;
        # have to store the instance var $!width into a `lexical` to 
        # be able to use within the regex below
        my $width = $!width;

        # grab up to $width-2 chars OR up to new line in the incoming string
        my $tmp = '';
        my @lines = ();
        for $!buffer.comb -> $char {
            if ($char eq "\n") { 
                @lines.push($tmp); 
                $tmp = ''; 
                next; 
            }
            else { 
                if ($tmp.chars == ($!width-2)) { 
                    @lines.push($tmp); 
                    $tmp = $char; 
                    next; 
                } 
                else { 
                    $tmp ~= $char; 
                } 
            }
        }; 
        @lines.push($tmp) if $tmp.chars > 0; 

        # if height of the $!buffer is more than window height, then we'll start
        # the window's $!buffer render from (@lines - $!height) to @lines end.
        my $start = (@lines.elems - ($!height-3) < 0) ??
                         0 !! (@lines.elems - ($!height-3));

        # render the window's $!buffer text
        for $start ..^ @lines -> $i {
            $!scr.write-xy($!xpos, $!ypos, @lines[$i] ~ ($!fill-char x (($!width-2) - @lines[$i].chars)), fore => $!fg); 
            $!xpos = $!x + 1;
            $!ypos++;
        }
        while ($!ypos <= $!y+$!height-2) {
            $!scr.write-xy($!xpos, $!ypos, ($!fill-char x ($!width-2)), fore => $!fg);
            $!xpos = $!x + 1;
            $!ypos++;
        }
    }
    method clear(:$char=" ", :$fore='black', :$back='black') {
        $!buffer = '';
        $!scr.fill(x => $!x + 1,
                    y => $!y + 2,
                    width => $!width - 2,
                    height => $!height - 3,
                    char => $char,
                    fore => $fore,
                    back => $back);
    }
    method move-xy(:$x=$!x, :$y=$!y) {
        my $temp-x = ($x < 0) ?? 0 !! (($x > $!scr.width) ?? $!scr.width !! $x);
        my $temp-y = ($y < 0) ?? 0 !! (($y > $!scr.height) ?? $!scr.height !! $y);
        $!scr.fill(x => $!x, y => $!y, width => $!width, height => $!height);
        $!x = $temp-x;
        $!y = $temp-y;
        self.draw;
    }
}

class Dashboard {

    has $.screen;
    has $.fg;
    has $.bg;
    has $.fill-char = ' ';

    method TWEAK {
        $!screen = Screen.new(fg => 'red',
            bg => 'black',
            fill-char => "\x[2591]");
    }

    method create-window(*%opts) {
        my $win = Window.new(scr => $!screen, |%opts);        
        $win;
    }

    method add-window(*@wins) {
        $!screen.add-window(@wins);
    }

    method run() {
        loop { 
            my $key = ReadInput();
            next if not defined $key;
            last if $key eq 'q';
            $!screen.dispatch-key($key);            
        }

        self.cleanup;
    }

    method cleanup {
        # cleanup screen
        $!screen.cls;
        $!screen.show-cursor;
    }

}
