unit module Term::Transkey;

use Term::ReadKey:from<Perl5>;

sub ReadInput() is export {
    ReadMode 3;
    my @codes = ();    
    my $key = ReadKey(0);
    @codes.push($key);
    if ( $key.ord == 27 ) {
        while ( defined ($key = ReadKey(-1))) {
            @codes.push($key);
        }

        ReadMode(0);
        my $key-string = @codes.map(-> $k { $k.ord }).join('-');
        return do given $key-string {
            when '27' { '<ESCAPE>' }
            when '27-79-80' { '<F1>' }
            when '27-79-81' { '<F2>' }
            when '27-79-82' { '<F3>' }
            when '27-79-83' { '<F4>' }
            when '27-91-49-53-126' { '<F5>' }
            when '27-91-49-55-126' { '<F6>' }
            when '27-91-49-56-126'  { '<F7>' }
            when '27-91-49-57-126'  { '<F8>' }
            when '27-91-50-48-126'  { '<F9>' }
            when '27-91-50-49-126'  { '<F10>' }
            when '27-91-50-51-126'  { '<F11>' }
            when '27-91-50-52-126'  { '<F12>' }
            when '27-91-50-126'  { '<INSERT>' }
            when '27-91-49-126'  { '<HOME>' }
            when '27-91-51-126'  { '<DELETE>' }
            when '27-91-52-126'  { '<END>' }
            when '27-91-53-126'  { '<PAGE UP>' }
            when '27-91-54-126'  { '<PAGE DOWN>' }
            when '27-91-65'  { '<UP>' }
            when '27-91-66'  { '<DOWN>' }
            when '27-91-67'  { '<RIGHT>' }
            when '27-91-68'  { '<LEFT>' }
            when '27-91-50-57-126'  { '<CONTEXT>' }
            when '10'  { '<ENTER>' }
            when '13'  { '<ENTER>' }
            when '127'  { '<BACKSPACE>' }
            default { $key-string }
        };  
    }
    else {
        ReadMode(0);
        return $key;
    }
    

    
}