package Class::PObject::Driver::sqlite;

# $Id: sqlite.pm,v 1.5.4.2 2003/09/06 10:14:58 sherzodr Exp $

use strict;
#use diagnostics;
use Log::Agent;
use vars ('@ISA', '$VERSION');
require Class::PObject::Driver::DBI;

@ISA = ('Class::PObject::Driver::DBI');
$VERSION = '2.00';


sub save {
    my ($self, $object_name, $props, $columns) = @_;

    my $dbh                 = $self->dbh($object_name, $props)        or return;
    my $table               = $self->_tablename($object_name, $props, $dbh) or return;
    my ($sql, $bind_params);

    # checking if $columns->{id} exists:
    if ( $columns->{id} ) {
        #let's check if there is a database record for this column already
        if ( $self->count($object_name, $props, {id=>$columns->{id}}) ) {
            ($sql, $bind_params) = $self->_prepare_update($table, $columns, {id=>$columns->{id}});
        }
    }
    unless ( $sql ) {
        ($sql, $bind_params)= $self->_prepare_insert($table, $columns)
    }
    my $sth                 = $dbh->prepare( $sql );
    unless ( $sth->execute(@$bind_params) ) {
        $self->errstr("couldn't save/update the record ($sth->{Statement}): " . $sth->errstr);
        logerr $self->errstr;
        return undef
    }
    return $dbh->func("last_insert_rowid")
}









sub dbh {
    my ($self, $object_name, $props) = @_;

    my $datasource = $props->{datasource};

    if ( defined $self->stash($datasource) ) {
        return $self->stash($datasource)
    }
    require DBI;
    my $dbh = DBI->connect("dbi:SQLite:dbname=$datasource", "", "", {RaiseError=>0, PrintError=>0});
    unless ( defined $dbh ) {
        $self->errstr("couldn't connect to 'DSN': " . $DBI::errstr);
        return undef
    }
    $dbh->{FetchHashKeyName} = 'NAME_lc';
    $self->stash($datasource, $dbh);
    $self->stash('close', 1);
    return $dbh
}




sub _tablename {
    my ($self, $object_name, $props, $dbh) = @_;

    my $table_name = lc $object_name;
    $table_name =~ s/\W+/_/g;
    return $table_name
}

1;
__END__;

=head1 NAME

Class::PObject::Driver::sqlite - SQLite Pobject Driver

=head1 SYNOPSIS

    use Class::PObject;
    pobject Person => {
        columns => ['id', 'name', 'email'],
        driver  => 'sqlite',
        datasource => 'data/website.db'
    };

=head1 DESCRIPTION

Class::PObject::Driver::sqlite is a direct subclass of L<Class::PObjecet::Driver::DBI|Class::PObject::Driver::DBI>.
It inherits all the base functionality needed for all the DBI-related classes. For details
of these methods and their specifications refer to L<Class::PObject::Driver|Class::PObject::Driver> and
L<Class::PObject::Driver::DBI|Class::PObject::Driver::DBI>.

=head2 DATASOURCE

I<datasource> attribute should be a string pointing to a database file. Multiple objects may have
the same datasource, in which case all the related tables will be stored in a single database.

=head1 METHODS

Class::PObject::Driver::sqlite (re-)defines following methods of its own

=over 4

=item *

C<dbh()> base DBI method is overridden with the version that creates a DBI handle
using L<DBD::SQLite|DBD::SQLite> I<datasource> attribute.

=item *

C<save()> - stores/updates the object

=back

=head1 SEE ALSO

L<Class::PObject>, 
L<Class::PObject::Driver::csv>,
L<Class::PObject::Driver::file>, 
L<Class::PObject::Driver::mysql>

=head1 COPYRIGHT AND LICENSE

For author and copyright information refer to Class::PObject's L<online manual|Class::PObject>.

=cut
