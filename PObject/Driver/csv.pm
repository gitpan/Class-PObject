package Class::PObject::Driver::csv;

# $Id: csv.pm,v 1.4 2003/06/09 09:08:38 sherzodr Exp $

use strict;
use base ('Class::PObject::Driver');
use Carp;
use File::Spec;

# Preloaded methods go here.
sub save {
  my $self = shift;
  my ($object_name, $props, $columns) = @_;

  unless ( defined $columns->{id} ) {
    $columns->{id} = $self->_generate_id($object_name, $props);
  }

  my $dbh = $self->dbh($object_name, $props) or return;
  my $table = $self->_get_tablename($object_name, $props) or return;
  
  my ($set_str, @set, @holder);

  while ( my($k, $v) = each %$columns ) {
    push @set, "$k=?";
    push @holder, $v;
  }
  
  #die Dumper([\@set, \@holder]);

  $set_str = "SET " . join(', ', @set);
  #die $set_str;

  # check if this id already exists:
  my $exists = $dbh->selectrow_array(qq|SELECT * FROM $table WHERE id=?|, undef, $columns->{id});
  if ( $exists ) {
    my $sth = $dbh->prepare(qq|UPDATE $table $set_str WHERE id=?|);
    #die $sth->{Statement};
    unless($sth->execute(@holder, $columns->{id})) {
      $self->error("couldn't execute '$sth->{Statement}': " . $sth->errstr);
      return undef;
    }
  } else {
    my (@cols, @values);
    while ( my ($k, $v) = each %$columns ) {
      push @cols, $k;
      push @values, '?';
    }    
    my $sth = $dbh->prepare(sprintf(qq|INSERT INTO $table (%s) VALUES(%s)|, join(', ', @cols), join(', ', @values)));
    #die $sth->{Statement};
    unless($sth->execute(@holder)) {
      $self->error("couldn't execute query '$sth->{Statement}': " . $sth->errstr);
      return undef;
    }    
  }
  return $columns->{id};
}







sub _generate_id {
  my ($self, $object_name, $props) = @_;

  my $dbh = $self->dbh($object_name, $props) or return;
  my $table = $self->_get_tablename($object_name, $props) or return;

  # figuring out the 'last' id:
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

  #die Dumper($terms);
  
  my (@where, @holder, $where_str, $order_str, $limit_str);
  while ( my($k, $v) = each %$terms ) {
    push @where, "$k=?";
    push @holder, $v;
  }

  if ( defined $args->{'sort'} ) {
    $args->{direction} ||= 'asc';
    $order_str = sprintf("OREDER BY %s %s", $args->{'sort'}, $args->{direction});  
  } else {
    $order_str = "";
  }

  if ( defined $args->{limit} ) {
    $args->{offset} ||= 0;
    $limit_str = sprintf("LIMIT %d, %d", $args->{offset}, $args->{limit});
  } else {
    $limit_str = "";
  }

  if ( @where ) {
    $where_str = "WHERE " . join(" AND ", @where);
  } else {
    $where_str = "";
  }

  my $dbh   = $self->dbh($object_name, $props) or return;
  my $table = $self->_get_tablename($object_name, $props) or return;
  my $sth   = $dbh->prepare(qq|SELECT * FROM $table $where_str $order_str $limit_str|);    
  $sth->execute(@holder);
  unless ( $sth->rows ) {
    $self->error("No objects returned");
    return undef;
  }

  my @rows = ();
  while ( my $row = $sth->fetchrow_hashref() ) {
    push @rows, $row;
  }
  return \@rows;
}


sub remove {
  my $self = shift;
  my ($object_name, $props, $id)  = @_;

  unless ( defined $id ) {
    return;
  }

  my $dbh = $self->dbh($object_name, $props) or return;
  my $table = $self->_get_tablename($object_name, $props) or return;
  $dbh->do(qq|DELETE FROM $table WHERE id=?|, undef, $id);
}


sub remove_all {
  my $self = shift;
  my ($object_name, $props) = @_;

  my $dbh = $self->dbh($object_name, $props) or return undef;
  my $table = $self->_get_tablename($object_name, $props);
  return $dbh->do(qq|DELETE FROM $table|);
}



sub dbh {
  my ($self, $object_name, $props) = @_;

  if ( defined $self->stash('dbh') ) {
    return $self->stash('dbh');
  }
  
  require DBI;  
  my $dir = $self->_get_dirname($props);
  my $dbh = DBI->connect("DBI:CSV:f_dir=$dir");
  unless ( defined $dbh ) {
    $self->error("cannot connect: $DBI::errstr");
    return undef;
  }
  my $table = $self->_get_tablename($object_name, $props);
  unless ( -e File::Spec->catfile($dir, $table) ) {
    my $columns = $props->{columns};    
    my $sql_str = "CREATE TABLE $table (";
    for my $colname ( @$columns ) {
      $sql_str .= "$colname BLOB, ";
    }
    $sql_str .= ")";
    my $sth = $dbh->prepare($sql_str);
    unless($sth->execute()) {
      $self->error("couldn't execute statement '$sth->{Statement}: " . $sth->errstr);
      return undef;
    }
    #die $sql_str;
  }
  $self->stash('dbh', $dbh);
  $self->stash('close', 1);
  return $self->dbh($object_name, $props);
}






sub DESTROY {
  my $self = shift;
  
  if ( $self->stash('close') && defined($self->stash('dbh')) ) {    
    my $dbh = $self->stash('dbh');
    $dbh->disconnect();
  }
}




sub _get_dirname {
  my $self = shift;
  my $props = shift;
  
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
  my ($self, $object_name, $props) = @_;

  my $datasource = $props->{datasource} || {};
  my $table  = $datasource->{Table};

  unless ( defined $table ) {
    $table = $object_name;
    $table =~ s/\W+/_/g;    
  }
  return lc($table);
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
