

# $Id: 01basic_file.t,v 1.6 2003/08/25 12:59:11 sherzodr Exp $
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

my $t = new Class::PObject::Test::Basic('file', File::Spec->catfile('data', 'file'));
$t->run();




