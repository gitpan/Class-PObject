

# $Id: 16basic_db_file.t,v 1.4.2.1 2003/09/06 09:57:08 sherzodr Exp $

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
my $t = new Class::PObject::Test::Basic('db_file', File::Spec->catfile('data', 'basic', 'db_file'));
$t->run();