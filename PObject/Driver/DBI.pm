package Class::PObject::Driver::DBI;

# $Id: DBI.pm,v 1.3 2003/08/23 10:36:44 sherzodr Exp $

use strict;
use Carp;
use Class::PObject::Driver;
use vars ('$VERSION', '@ISA');

@ISA = ('Class::PObject::Driver');
$VERSION = '1.00';


sub _prepare_where_clause {
    my ($self, $terms) = @_;

    $terms ||= {};

    # if no terms present, just return an empty string
    unless ( keys %$terms ) {
        return ("", ());
    }

    my ($sql, @where, @bind_params);

    while ( my ($k, $v) = each %$terms ) {
        push @where, "$k=?";
        push @bind_params, $v
    }

    $sql = "WHERE " . join (" AND ", @where);
    return ($sql, \@bind_params)
}



sub _prepare_select {
    my ($self, $table_name, $terms, $args) = @_;

    my ($sql, @where, @bind_params);

    my ($where_clause, $bind_params) = $self->_prepare_where_clause($terms);
    $sql = "SELECT * FROM $table_name " . $where_clause;

    if ( defined $args ) {
        $args->{limit}      ||= 1000;
        $args->{offset}     ||= 0;
        if ( $args->{'sort'} ) {
            $args->{direction}  ||= 'asc';
            $sql .= sprintf(" ORDER BY %s %s", $args->{'sort'}, $args->{direction})
        }
        $sql .= sprintf(" LIMIT %d, %d", $args->{offset}, $args->{limit})
    }
    return ($sql, $bind_params)
}




sub _prepare_delete {
    my ($self, $table_name, $terms) = @_;

    my ($sql, @where, @bind_params);
    $sql = "DELETE FROM $table_name ";

    my ($where_clause, $bind_params) = $self->_prepare_where_clause($terms);
    $sql .= $where_clause;

    return ($sql, $bind_params)
}




sub _prepare_insert {
    my ($self, $table_name, $columns) = @_;

    my ($sql, @fields, @values, @bind_params);
    $sql = "INSERT INTO $table_name";

    while ( my ($k, $v) = each %$columns ) {
        push @fields, $k;
        push @values, '?';
        push @bind_params, $v
    }

    $sql .= sprintf(" (%s) VALUES(%s)", join(", ", @fields), join(", ", @values) );
    return ($sql, \@bind_params)
}





sub _prepare_update {
    my ($self, $table_name, $columns, $terms) = @_;

    my ($sql, @fields, @bind_params);
    $sql = "UPDATE $table_name SET ";

    while ( my ($k, $v) = each %$columns ) {
        push @fields, "$k=?";
        push @bind_params, $v
    }

    $sql .= join (", ", @fields);

    my ($where_clause, $where_params) = $self->_prepare_where_clause($terms);
    $sql .= " " . $where_clause;

    return ($sql, [@bind_params, @$where_params])
}







sub _tablename {
    my ($self, $object_name, $props, $dbh) = @_;

    if ( defined $props->{datasource}->{Table} ) {
        return $props->{datasource}->{Table}
    }

    my $table_name = lc $object_name;
    $table_name =~ s/\W+/_/g;

    return $table_name
}







sub load {
    my $self = shift;
    my ($object_name, $props, $terms, $args) = @_;

    if ( $terms && (ref($terms) ne 'HASH') && ($terms =~m/^\d+$/) ) {
        $terms = {id => $_[2]}
    }

    my $dbh   = $self->dbh($object_name, $props)                  or return;
    my $table = $self->_tablename($object_name, $props, $dbh) or return;
    my ($sql, $bind_params)   = $self->_prepare_select($table, $terms, $args);

    my $sth   = $dbh->prepare( $sql );
    unless( $sth->execute(@$bind_params) ) {
        $self->errstr($sth->errstr);
        return undef
    }

    unless ( $sth->rows ) {
        return []
    }

    my @rows = ();
    while ( my $row = $sth->fetchrow_hashref() ) {
        push @rows, $row
    }
    return \@rows
}







sub remove {
    my $self = shift;
    my ($object_name, $props, $id)  = @_;

    unless ( defined $id ) {
        $self->errstr("remove(): don't know what to remove. 'id' is missing");
        return undef
    }

    my $dbh                 = $self->dbh($object_name, $props)              or return;
    my $table               = $self->_tablename($object_name, $props, $dbh) or return;
    my ($sql, $bind_params) = $self->_prepare_delete($table);

    my $sth                 = $dbh->prepare( $sql );
    unless ( $sth->execute($id) ) {
        $self->errstr($sth->errstr);
        return undef
    }
    return $id
}





sub remove_all {
    my $self  = shift;
    my ($object_name, $props, $terms) = @_;

    my $dbh                 = $self->dbh($object_name, $props)              or return;
    my $table               = $self->_tablename($object_name, $props, $dbh) or return;
    my ($sql, $bind_params) = $self->_prepare_delete($table, $terms);

    my $sth   = $dbh->prepare( $sql );
    unless ( $sth->execute(@$bind_params) ) {
        $self->errstr($sth->errstr);
        return undef
    }
    return 1
}




sub count {
    my $self = shift;
    my ($object_name, $props, $terms) = @_;

    my $dbh                         = $self->dbh($object_name, $props)  or return;
    my $table                       = $self->_tablename($object_name, $props, $dbh) or return;
    my ($where_clause, $bind_params)= $self->_prepare_where_clause($terms);
    my $sql                         = "SELECT COUNT(*) FROM $table " . $where_clause;

    my $sth                         = $dbh->prepare( $sql );
    unless ( $sth->execute( @$bind_params ) ) {
        $self->errstr($sth->errstr);
        return undef
    }

    return $sth->fetchrow_array || 0
}



1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

Class::PObject::Driver::DBI - Base class for all DBI-related drivers

=head1 SYNOPSIS

    package Class::PObject::YourDriver;
    use Class::PObject::Driver::DBI;
    @ISA = ('Class::PObject::Driver::DBI');

    sub save {
        my ($self, $pobject_name, \%properties, \%columns) = @_;

        ...
    }

    sub dbh {
        my ($self, $pobject_name, \%properties) = @_;

        ...
    }

=head1 ABSTRACT

    Class::PObject::Driver::DBI is a subclass of Class::PObject::Driver.
    Provides all the necessary base methods/utilities for writing
    DBI-related pobject drivers.

=head1 STOP!

If you just want to be able to use Class::PObject> this manual is not for you.
This is for those willing to write I<pobject> drivers to support other database
systems and storage devices.

If you just want to be able to use Class::PObject, you should refer to its
L<online manual|Class::PObject> instead.

=head1 DESCRIPTION

Class::PObject::Driver::DBI is a direct subclass of L<Class::PObject::Driver|Class::PObject::Driver>
and overrides the methods provided in Class::PObject::Driver with those more relevant
to RDBMS engines.

It uses ANSI-SQL syntax, so most of the base methods should perform as expected for most
RDBMS that supports ANSI-SQL syntax.

For those that don't, you can override necessary methods from within your driver class.
This manual will not discuss the list of base methods, for they all are documented in
L<Class::PObject::Driver|Class::PObject::Driver>. Please refer to the L<manual|Class::PObject::Driver>
for gory details.

=head1 REQUIRED METHODS

Once your driver inherits from Class::PObject::Driver::DBI, most of the base methods, such as
C<load()>, C<remove()>, C<remove_all()>, C<count()> will already be defined for you, so you may not
even have to defined those methods.

The only methods required to be defined are C<save()> and C<dbh()>.
For details on C<save()> method, refer to L<Class::PObject::Driver|Class::PObject::Driver>.

=over 4

=item *

C<dbh($self, $pobject_name, \%properties)> - will be called by other base methods whenever
a database handle is needed. It receives all the standard arguments (L<Class::PObject::Driver>)

If your project consists of several pobjects, which is very common, you may want to C<stash()>
the created database handle to ensure Class::PObject will be able to re-use the same object
over instead of having to establish connection each time. This can get too costly too soon.

=back

=head1 OTHER METHODS

The list of all other standard driver methods can be found in L<Class::PObject::Driver|Class::PObject::Driver>.

Class::PObject::Driver::DBI also provides following private/utility methods that are called
by other driver methods to create SQL statements and/or clauses.

You may override these methods to affect the creation of SQL statements for your specific database
instead of having to re-define the standard driver methods.

All the methods prefixed with I<_prepare_> string return an array of two elements.
First is the C<$sql>, which holds the relevant ANSI-SQL statement with possible placeholders,
and second is C<\@bind_params>, which holds the list of all the values for the place holders
in the C<$sql>.

=over 4

=item *

C<_prepare_where_clause($self, \%terms)> - prepares a I<WHERE> SQL clause. This method is
primarily called from within C<_prepare_select()>, C<_prepare_update()>,
C<_prepare_delete()> and C<count()> methods.

Example:

    my ($sql, $bind_params) = $self->_prepare_where_clause({name=>'sherzod', is_admin=>'1'});

    # $sql is "WHERE name=?" AND is_admin=>?
    # $bind_params is ['sherzod', 1]

=item *

C<_prepare_select($self, $table_name, \%terms, \%args)> - prepares a I<SELECT> SQL statement,
given $table_name, \%terms and \%args. The last two arguments are the same as the ones passed
to C<load()> pobject method.

Example:

    my ($sql, $bind_params) = $self->_prepare_select('authors', {is_admin =>1},
                                                                {limit  => 10,
                                                                 offset => 0,
                                                                 sort   => 'name',
                                                                 direction=>'asc'});

C<$sql> will hold

    SELECT * FROM authors WHERE is_admin = ?
        ORDER BY name ASC LIMIT 0, 10

C<$bind_params> will hold C<[1]>

If your particular database engine requires a slightly different I<SELECT> syntax, you can override
this method from within your class.

=item *

C<_prepare_update($self, $table_name, \%columns, \%terms)> is similar to C<_prepare_select()>,
but builds an I<UPDATE> SQL statement

=item *

C<_prepare_insert($self, $table_name, \%columns)> builds an I<INSERT> SQL statement

=item *

C<_prepare_delete($self, $table_name, \%terms)> builds a I<DELETE> SQL statement

=item *

C<_tablename($self, $pobject_name, $props, $dbh)> returns a name of the table
this particular object should belong to. If I<pobject> declarations's I<datasource>
attribute already defined I<Table> name, this will be returned. Otherwise it will
recover the table name from the $pobject_name.

Usually C<_tablename()> doesn't need to be overridden, because by default it does the
right thing. You can override it, for example, if you want all of your tables to have
a specific prefix regardless of the C<$pobject_name> or even C<$datasource-E<gt>{Table}>.

Most of the base methods call C<_tablename()> to get the name of the table to include
it into SQL statements.

=back

=head1 SEE ALSO

L<Class::PObject::Driver>

=head1 AUTHOR

Sherzod B. Ruzmetov, E<lt>sherzodr@cpan.orgE<gt>, http://author.handalak.com/

=head1 COPYRIGHT AND LICENSE

Copyright 2003 by Sherzod B. Ruzmetov.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
