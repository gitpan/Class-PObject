

# $Id: 64types_mysql.t,v 1.2 2003/09/08 15:24:55 sherzodr Exp $

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
    $dbh->do(qq|DROP TABLE IF EXISTS po_user|);
    $dbh->do(qq|
        CREATE TABLE po_user (
            id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
            name VARCHAR(80),
            login VARCHAR(40),
            psswd CHAR(30),
			activation_key CHAR(32)
        )|);
};

if ( $@ ) {
    print "1..0 #Skipped: $@\n";
    exit(0)
}

use Class::PObject::Test::Types;
my $t = new Class::PObject::Test::Types('mysql', {
						DSN=>"dbi:mysql:$ENV{MYSQL_DB}", 
						User=>$ENV{MYSQL_USER}, 
						Password=>$ENV{MYSQL_PASSWORD}, 
						Table=>'po_user'} );
$t->run();
