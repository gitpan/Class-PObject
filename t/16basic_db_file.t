

# $Id: 16basic_db_file.t,v 1.1 2003/08/23 13:15:13 sherzodr Exp $

BEGIN {
    for ( "DB_File" ) {
        eval "require $_";
        if ( $@ ) {
            print "1..0 #Skipped: $_ is not available\n";
            exit(0)
        }
    }
}

use Class::PObject::Test::Basic;
my $t = new Class::PObject::Test::Basic('DB_File', 'data');
$t->run();
