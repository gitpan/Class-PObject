

# $Id: 73hasa_db_file.t,v 1.1.2.1 2003/09/06 09:57:08 sherzodr Exp $

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
use Class::PObject::Test::HAS_A;
my $t = new Class::PObject::Test::HAS_A('db_file', File::Spec->catfile('data', 'has_a', 'db_file'));
$t->run();
