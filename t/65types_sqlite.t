

# $Id: 65types_sqlite.t,v 1.3 2003/09/09 00:12:02 sherzodr Exp $

BEGIN {
    for ( "DBD::SQLite" ) {
        eval "require $_";
        if ( $@ ) {
            print "1..0 #Skipped: $_ is not available\n";
            exit(0)
        }
    }
}

require File::Spec;
my $db = File::Spec->catfile('data', 'types', 'sqlite');

if ( -e $db ) {
    unlink($db)
}
my $dbh = DBI->connect("dbi:SQLite:dbname=$db", "", "");
eval {
    $dbh->do(qq|
        CREATE TABLE user (
            id INTEGER PRIMARY KEY,
            name VARCHAR(200),
	    psswd VARCHAR(200),
	    activation_key VARCHAR(32),
	    login VARCHAR(200)
        )|)
};

use Class::PObject::Test::Types;
my $t = new Class::PObject::Test::Types('sqlite', $db);
$t->run()

