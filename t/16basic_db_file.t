

# $Id: 16basic_db_file.t,v 1.2 2003/08/23 14:31:32 sherzodr Exp $

BEGIN {
    for ( "DB_File" ) {
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
