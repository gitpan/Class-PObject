

# $Id: 72hasa_mysql.t,v 1.1.2.1 2003/09/06 09:57:08 sherzodr Exp $

BEGIN {
    for ( "DBI", "DBD::mysql" ) {
        eval "require $_";
        if ( $@ ) {
            print "1..0 #Skipped: $_ is not available\n";
            exit(0)
        }
    }
    unless ( $ENV{MYSQL_DB} && $ENV{MYSQL_USER} ) {
        print "1..0 #Skipped: Read INSTALL for details on running mysql-related tests";
        exit(0)
    }
}

my $dbh = DBI->connect("dbi:mysql:$ENV{MYSQL_DB}", $ENV{MYSQL_USER}, $ENV{MYSQL_PASSWORD}, {PrintError=>0});
eval {
    $dbh->do(qq|DROP TABLE IF EXISTS po_author|);
    $dbh->do(qq|
        CREATE TABLE po_author (
            id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
            name VARCHAR(200)
        )|);
    $dbh->do(qq|DROP TABLE IF EXISTS po_article|);
    $dbh->do(qq|
        CREATE TABLE po_article (
            id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
            title VARCHAR(200),
            author INT UNSIGNED NOT NULL
        )|);
};

if ( $@ ) {
    print "1..0 #Skipped: $@\n";
    exit(0)
}

use Class::PObject::Test::HAS_A;
my $t = new Class::PObject::Test::HAS_A('mysql', {Handle=>$dbh});
$t->run();
