

# $Id$

BEGIN {
    for ( "Storable" ) {
        eval "require $_";
        if ( $@ ) {
            print "1..0 #Skipped: $_ is not available\n";
            exit(0)
        }
    }
}


use File::Spec;
use Class::PObject::Test::Basic;

my $t = new Class::PObject::Test::Basic(undef, File::Spec->catfile('data', 'basic', 'file'));
$t->run();




