package Class::PObject::Driver::csv;

# $Id: csv.pm,v 1.10 2003/08/23 10:36:44 sherzodr Exp $

use strict;
use Carp;
use Log::Agent;
use File::Spec;
use vars ('$VERSION', '@ISA');

require Class::PObject::Driver::DBI;
@ISA = ('Class::PObject::Driver::DBI');


sub save {
    my $self = shift;
    my ($object_name, $props, $columns) = @_;

    # if an id doesn't already exist, we should create one.
    # refer to generate_id() for the details
    unless ( defined $columns->{id} ) {
        $columns->{id} = $self->generate_id($object_name, $props)
    }

    my $dbh   = $self->dbh($object_name, $props)                or return;
    my $table = $self->_tablename($object_name, $props, $dbh)   or return;
  
    my $exists = $self->count($object_name, $props, {id=>$columns->{id}});
    if ( $exists ) {
        my ($sql, $bind_params) = $self->_prepare_update($table, $columns, {id=>$columns->{id}});
        my $sth = $dbh->prepare( $sql );
        unless( $sth->execute(@$bind_params) ) {
            $self->error("couldn't execute '$sth->{Statement}': " . $sth->errstr);
            return undef
        }
    } else {
        my ($sql, $bind_params) = $self->_prepare_insert($table, $columns);
        my $sth = $dbh->prepare( $sql );
        unless($sth->execute(@$bind_params)) {
            $self->error("couldn't execute query '$sth->{Statement}': " . $sth->errstr);
            return undef
        }
    }
    return $columns->{id}
}







sub generate_id {
    my ($self, $object_name, $props) = @_;

    my $dbh   = $self->dbh($object_name, $props)                  or return;
    my $table = $self->_tablename($object_name, $props, $dbh)     or return;

    my $last_id = $dbh->selectrow_array(qq|SELECT id FROM $table ORDER BY id DESC LIMIT 1|);
    return ++$last_id
}





sub dbh {
    my $self = shift;
    my ($object_name, $props) = @_;

    if ( defined $props->{datasource}->{Handle} ) {
        return $props->{datasource}->{Handle}->{Name}
    }

    my $dir          = $self->_dir($props) or return;
    my $stashed_name = "f_dir=$dir";
    
    if ( defined $self->stash($stashed_name) ) {
        return $self->stash($stashed_name)
    }

    require DBI;
    
    my $dbh = DBI->connect("DBI:CSV:f_dir=$dir");
    unless ( defined $dbh ) {
        $self->error($DBI::errstr);
        return undef
    }
    $self->stash($stashed_name, $dbh);
    $self->stash('close', 1);
    return $dbh
}



sub _dir {
    my $self    = shift;
    my ($props) = @_;
  
    my $datasource = $props->{datasource} || {};
    my $dir        = $datasource->{Dir};
    unless ( defined $dir ) {
        $dir = File::Spec->tmpdir
    }
    unless ( -e $dir ) {
        require File::Path;
        unless(File::Path::mkpath($dir)) {
            $self->error("couldn't create datasource '$dir': $!");
            return undef
        }
    }
    return $dir
}







sub _tablename {
    my ($self, $object_name, $props, $dbh) = @_;

    my $table = $self->SUPER::_tablename($object_name, $props);

    my $dir   = $self->_dir($props) or return;
    if ( -e File::Spec->catfile($dir, $table) ) {
        return $table
    }

    my @sets    = ();
    for my $colname ( @{$props->{columns}} ) {
        push @sets, "$colname BLOB";
    }

    my $sql_str = sprintf("CREATE TABLE %s (%s)", $table, join (", ", @sets));
    my $sth = $dbh->prepare($sql_str);
    unless($sth->execute()) {
        $self->error($sth->{Statement} . ': ' . $sth->errstr);
        return undef
    }
    return $table
}



1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

Class::PObject::Driver::csv - CSV Pobject Driver

=head1 SYNOPSIS

    use Class::PObject;
    pobject Person => {
        columns => ['id', 'name', 'email'],
        driver  => 'csv',
        datasource => {
            Dir => 'data/',
            Table => 'person'
        }
    };

=head1 DESCRIPTION

Class::PObject::Driver::csv is a direct subclass of L<Class::PObjecet::Driver::DBI|Class::PObject::Driver::DBI>.
It inherits all the base functionality needed for all the DBI-related classes. For details
of these methods and their specifications refer to L<Class::PObject::Driver|Class::PObject::Driver> and
L<Class::PObject::Driver::DBI|Class::PObject::Driver::DBI>.

=head2 DATASOURCE

I<datasource> attribute should be in the form of a hashref. The following keys are supported

=over 4

=item *

C<Dir> - points to the directory where the CSV files are stored. If this is missing
will default to your system's temporary folder.

=item *

C<Table> - defines the name of the table that objects will be stored in. If this is missing
will default to the name of the object, non-alphanumeric characters replaced with underscore (C<_>).

=back

=head1 METHODS

Class::PObject::Driver::csv (re-)defines following methods of its own

=over 4

=item *

C<dbh()> base DBI method is overridden with the version that creates a DBI handle
through L<DBD::CSV|DBD::CSV>.

=item *

C<save()> either builds a SELECT SQL statement by calling base C<_prepare_select()> 
if the object id is missing, or builds an UPDATE SQL statement by calling base C<_prepare_update()>.

If the ID is missing, calls C<generate_id()> method, which returns a unique ID for the object.

=item *

C<generate_id($self, $pobject_name, \%properties)> returns a unique ID for new objects. This determines
the new ID by performing a I<SELECT id FROM $table ORDER BY id DESC LIMIT 1> SQL statement to 
determine the latest inserted ID.

=item *

C<_tablename($self, $pobject_name, \%properties)>

Redefines base method C<_tablename()>. If the table is missing, it will also create the table
for you.

=back

=head1 SEE ALSO

L<Class::PObject>, L<Class::PObject::Driver::mysql>,
L<Class::PObject::Driver::file>

=head1 AUTHOR

Sherzod Ruzmetov E<lt>sherzodr@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2003 by Sherzod B. Ruzmetov.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut
