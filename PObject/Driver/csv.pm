package Class::PObject::Driver::csv;

# $Id: csv.pm,v 1.5 2003/06/20 00:04:41 sherzodr Exp $

use strict;
use base ('Class::PObject::Driver');
use Carp;
use File::Spec;



# Preloaded methods go here.
sub save {
  my $self = shift;
  my ($object_name, $props, $columns) = @_;

  # if an id doesn't already exist, we should create one.
  # refer to _generate_id() for the details
  unless ( defined $columns->{id} ) {
    $columns->{id} = $self->_generate_id($object_name, $props);
  }

  my $dbh   = $self->dbh($object_name, $props)                  or return;
  my $table = $self->_get_tablename($object_name, $props, $dbh) or return;
  
  # we should know generate SQL statement for inserting/upgrating the object
  # record
  my ($set_str, @set, @holder);

  # to do it, we iterate over each column to be stored
  while ( my($k, $v) = each %$columns ) {
    # build @set and @holder arrays - the easiest and secure way
    # of creating SQL statement dynamically
    push @set,    "$k=?";
    push @holder, $v;
  }
  
  # check if this id already exists:
  my $exists = $dbh->selectrow_array(qq|SELECT * FROM $table WHERE id=?|, undef, $columns->{id});
  if ( $exists ) {
    # if it does, we should update the existing record:
    my $sql_str = sprintf("UPDATE %s SET %s WHERE id=?", $table, join (", ", @set));
    my $sth = $dbh->prepare($sql_str);
    unless($sth->execute(@holder, $columns->{id})) {
      $self->error("couldn't execute '$sth->{Statement}': " . $sth->errstr);
      return undef;
    }
  } else {
    # if it doesn't, insert it as a new record
    my (@cols, @values);
    while ( my ($k, $v) = each %$columns ) {
      push @cols,   $k;
      push @values, '?';
    }
    my $sql_str = sprintf("INSERT INTO %s (%s) VALUES(%s)", $table, join(', ', @cols), join(', ', @values));
    my $sth = $dbh->prepare($sql_str);
    unless($sth->execute(@holder)) {
      $self->error("couldn't execute query '$sth->{Statement}': " . $sth->errstr);
      return undef;
    }
  }
  return $columns->{id};
}







sub _generate_id {
  my ($self, $object_name, $props) = @_;

  my $dbh   = $self->dbh($object_name, $props)                  or return;
  my $table = $self->_get_tablename($object_name, $props, $dbh) or return;

  my $last_id = $dbh->selectrow_array(qq|SELECT id FROM $table ORDER BY id DESC LIMIT 1|);
  return ++$last_id;
}







sub load {
  my $self = shift;
  my ($object_name, $props, $terms, $args) = @_;

  if ( $terms && (ref($terms) ne 'HASH') && ($terms =~m/^\d+$/) ) {
    $terms = {id => $_[2]};
  }

  $args ||= { };
  my (@where, @holder, $where_str, $order_str, $limit_str);
  $order_str = $limit_str = $where_str = "";

  # creating key/values for 'WHERE' clause
  while ( my($k, $v) = each %$terms ) {
    push @where, "$k=?";
    push @holder, $v
  }  
  if ( @where ) {
    $where_str = "WHERE " . join(" AND ", @where)
  }

  # creating an 'ORDER BY' clause
  if ( defined $args->{'sort'} ) {
    $args->{direction} ||= 'asc';
    $order_str = sprintf("ORDER BY %s %s", $args->{'sort'}, $args->{direction})
  }

  # creating 'LIMIT' clause
  if ( defined $args->{limit} ) {
    $args->{offset} ||= 0;
    $limit_str = sprintf("LIMIT %d, %d", $args->{offset}, $args->{limit});
  }

  my $dbh   = $self->dbh($object_name, $props)                  or return;
  my $table = $self->_get_tablename($object_name, $props, $dbh) or return;
  
  my $sth   = $dbh->prepare(qq|SELECT * FROM $table $where_str $order_str $limit_str|);    
  unless($sth->execute(@holder)) {
    $self->error($sth->errstr);
    return undef
  }
  unless ( $sth->rows ) {
    return []
  }

  my @rows = ();
  while ( my $row = $sth->fetchrow_hashref() ) {
    push @rows, $row
  }
  return \@rows;
}


sub remove {
  my $self = shift;
  my ($object_name, $props, $id)  = @_;

  unless ( defined $id ) {
    $self->error("remove(): don't know what to remove. 'id' is missing");
    return undef;
  }

  my $dbh = $self->dbh($object_name, $props) or return;
  my $table = $self->_get_tablename($object_name, $props, $dbh) or return;
  my $sth = $dbh->prepare(qq|DELETE FROM $table WHERE id=?|);
  unless ( $sth->execute($id) ) {
    $self->error($sth->errstr);
    return undef;
  }
  return $id;
}


sub remove_all {
  my $self  = shift;
  my ($object_name, $props) = @_;

  my $dbh   = $self->dbh($object_name, $props)                  or return;
  my $table = $self->_get_tablename($object_name, $props, $dbh) or return;
  my $sth   = $dbh->prepare(qq|DELETE FROM $table|);
  unless ( $sth->execute() ) {
    $self->error($sth->errstr);
    return undef;
  }
  return 1;
}



sub dbh {
  my $self = shift;
  my ($object_name, $props) = @_;

  my $dir          = $self->_get_dirname($props) or return;
  my $stashed_name = "dbh:$dir";

  if ( defined $self->stash($stashed_name) ) {
    return $self->stash($stashed_name);
  }
  
  require DBI;
  
  my $dbh = DBI->connect("DBI:CSV:f_dir=$dir");
  unless ( defined $dbh ) {
    $self->error("cannot connect: $DBI::errstr");
    return undef;
  }
  $self->stash($stashed_name, $dbh);
  $self->stash('close', 1);
  return $dbh;
}








sub DESTROY { }




sub _get_dirname {
  my $self    = shift;
  my ($props) = @_;
  
  my $datasource = $props->{datasource} || {};
  my $dir        = $datasource->{Dir};
  unless ( defined $dir ) {
    $dir = File::Spec->tmpdir();
  }
  unless ( -e $dir ) {
    require File::Path;
    unless(File::Path::mkpath($datasource->{Dir})) {
      $self->error("couldn't create datasource '$dir': $!");
      return undef;
    }
  }
  return $dir;
}




sub _get_tablename {
  my ($self, $object_name, $props, $dbh) = @_;

  my $table = undef;
  if ( $props->{Table} ) {
    $table = $props->{Table}
    
  } else {
    $object_name =~ s/\W+/_/g;
    $table       = lc($object_name)

  }

  my $dir   = $self->_get_dirname($props) or return;
  if ( -e File::Spec->catfile($dir, $table) ) {
    return $table;
  }
  
  my @sets    = ();
  for my $colname ( @{$props->{columns}} ) {
    push @sets, "$colname BLOB";
  }
  my $sql_str = sprintf("CREATE TABLE %s (%s)", $table, join (", ", @sets));
  my $sth = $dbh->prepare($sql_str);
  unless($sth->execute()) {
    $self->error($sth->{Statement} . ': ' . $sth->errstr);
    return undef;
  }
  return $table;
}



1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

Class::PObject::Driver::csv - csv driver for Class::PObject

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


=head1 WARNING

The driver is buggy. Use it ONLY if you want to get all the test scripts running.

=head1 DESCRIPTION

Comming soon...




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
