

# $Id: 21basic_sqlite.t,v 1.5 2003/09/09 00:12:02 sherzodr Exp $

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
my $db = File::Spec->catfile('data', 'basic', 'sqlite');

if ( -e $db ) {
    unlink($db)
}
my $dbh = DBI->connect("dbi:SQLite:dbname=$db", "", "");
eval {
    $dbh->do(qq|
        CREATE TABLE po_author (
            id INTEGER PRIMARY KEY,
            name VARCHAR(200),
            email VARCHAR(200),
            url VARCHAR(200)
        )|);
    $dbh->do(qq|
        CREATE TABLE po_article (
            id INTEGER PRIMARY KEY,
            title VARCHAR(200),
            author INTGER,
            rating INTEGER,
            content TEXT 
        )|);
};

use Class::PObject::Test::Basic;
my $t = new Class::PObject::Test::Basic('sqlite', $db);
$t->run()

