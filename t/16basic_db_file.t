

# $Id: 16basic_db_file.t,v 1.3 2003/08/25 12:59:12 sherzodr Exp $

BEGIN {
    for ( "DB_File", "Storable" ) {
        eval "require $_";
        if ( $@ ) {
            print "1..0 #Skipped: $_ is not available\n";
            exit(0)
        }
    }
}

use File::Spec;
use Class::PObject::Test::Basic;
my $t = new Class::PObject::Test::Basic('DB_File', File::Spec->catfile('data', 'db_file'));
$t->run();
