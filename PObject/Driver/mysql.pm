package Class::PObject::Driver::mysql;

# $Id: mysql.pm,v 1.3 2003/06/08 23:22:19 sherzodr Exp $

use strict;
use base ('Class::PObject::Driver');
use Carp;

# Preloaded methods go here.
sub save {
  my ($self, $object_name, $props, $columns) = @_;

  my $dbh = $self->dbh($object_name, $props) or croak "dbh() couldn't be created";  

  #die Dumper($columns);
  my ($set_str, $table, @set, @holder);
  $table = $self->_get_tablename($object_name, $props) or return;

  while ( my($k, $v) = each %$columns ) {
    push @set, "$k=?";
    push @holder, $v;
  }
  
  #die Dumper(\@set);
  $set_str = "SET " . join(', ', @set);
  my $sth = $dbh->prepare(qq|REPLACE INTO $table $set_str|);
  #die $sth->{Statement};
  $sth->execute(@holder);  
  return $dbh->{mysql_insertid};
}






sub load {
  my $self = shift;  
  my ($object_name, $props, $terms, $args) = @_;

  if ( $terms && (ref($terms) ne 'HASH') && ($terms =~m/^\d+$/) ) {
    $terms = {id => $_[2]};
  }

  $args ||= { };
  
  my (@where, @holder, $where_str, $order_str, $limit_str);
  while ( my($k, $v) = each %$terms ) {
    push @where, "$k=?";
    push @holder, $v;
  }

  if ( defined $args->{'sort'} ) {
    $args->{direction} ||= 'asc';
    $order_str = sprintf("ORDER BY %s %s", $args->{'sort'}, $args->{direction});  
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

  my $dbh   = $self->dbh($object_name, $props);
  my $table = $self->_get_tablename($object_name, $props) or return;
  my $sth   = $dbh->prepare(qq|SELECT * FROM $table $where_str $order_str $limit_str|);  
  unless($sth->execute(@holder)) {
    die $sth->{Statement};
  }
  unless ( $sth->rows ) {
    $self->error("No objects returned");
    return undef;
  }

  my @rows = ();
  while ( my $row = $sth->fetchrow_hashref() ) {
    push @rows, $row;
  }
  return @rows;
}


sub remove {
  my ($self, $object_name, $props, $id) = @_;
  
  unless ( defined $id ) {
    return;
  }

  my $dbh = $self->dbh($object_name, $props);
  my $table = $self->_get_tablename($object_name, $props) or return;
  $dbh->do(qq|DELETE FROM $table WHERE id=?|, undef, $id);
}


sub remove_all {
  my ($self, $object_name, $props) = @_;

  my $table = $self->_get_tablename($object_name, $props) or return;
  return $self->dbh($object_name, $props)->do(qq|DELETE FROM $table|);
}



sub dbh {
  my ($self, $object_name, $props) = @_;

  if ( defined $self->stash('dbh') ) {
    return $self->stash('dbh');
  }  
  # checking if datasource provides adequate information to us
  my $datasource = $props->{datasource};
  unless ( ref($datasource) ) {    
    $self->error("'datasource' is invalid");
    return undef;
  }

  if ( $datasource->{Handle} ) {
    $self->stash('dbh', $datasource->{Handle});
    return $datasource->{Handle};
  }
  
  my $dsn       = $datasource->{DSN} or die;
  my $db_user   = $datasource->{UserName};
  my $db_pass   = $datasource->{Password}; 

  #$self->stash('Table', $db_table);

  require DBI;
  my $dbh = DBI->connect($dsn, $db_user, $db_pass, {RaiseError=>0, PrintError=>0});
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




sub _get_tablename {
  my ($self, $object_name, $props) = @_;

  my $datasource = $props->{datasource};
  unless ( defined $datasource ) {
    $self->error("'datasource' is empty");
    return undef;
  }
  my $table = $datasource->{Table};
  unless ( $table ) {
    $object_name =~ s/\W+/_/g;
    $table = lc($object_name);
  }
  return $table;
}



1;
__END__;

=pod

=head1 NAME

Class::PObject::Driver::mysql - mysql driver for Class::PObject

=head1 SYNOPSIS  

  pobject Person => {
    columns   => ['id', 'name', 'email'],
    driver    => 'mysql',
    datasource=> {
      DSN => 'dbi:mysql:db_name',
      UserName => 'sherzodr',
      Password => 'secret',
      Table    => 'person',
    }
  };


=head1 DESCRIPTION

Class::PObject::Driver::mysql is a driver for Class::PObject for storing object data in mysql tables. Following class properties are required:

=over 4

=item * 

C<driver> - tells Class::PObject to use 'mysql' driver.

=item *

C<datasource> - gives the DBI details on how to connect to mysql database. C<datasource> should be in the form of a hashref, and should defined C<DSN>, C<UserName> and C<Password>. If you ommit C<Table>, it will default to the name of the object, lowercased, and non-alphanumeric values replaced with '_'. For example, if you define an object as:

  pobject Gallery::User => {
    columns => \@columns,
    driver => 'mysql',
    datasource=> {
      DSN => 'dbi:mysql:gallery',
      UserName => 'sherzodr',
      Password => 'secret',     
    }
  };

It will store itself into a table 'gallery_user' inside 'gallery' database. You can use 'Table' 'datasource' attribute if you want to override this default behavior:

  pobject Gallery::User => {
      columns => \@columns,
      driver => 'mysql',
      datasource=> {
        DSN => 'dbi:mysql:gallery',
        UserName => 'sherzodr',
        Password => 'secret',
        Table   => 'user'
    }
  };

=back

=head1 OBJECT STORAGE

Objects of the same type are stored in the same table, as seperate records. Each column of the object represents one column of the database table. It's required that you first create your tables for storing the objects.

=head1 ID GENERATION

There is no direct id generation routine available on this driver. It is directly manipulated by mysql's 'AUTO_INCREMENT' column type. It means, you should ALWAYS declare your 'id' columns as AUTO_INCREMENT PRIMARY KEY. 

=head1 SERIALIZATION

There is no direct serialization applied on the data. All the data goes as is into respective columns of the table.


=head1 SEE ALSO

L<Class::PObject>, L<Class::PObject::Driver::csv>,
L<Class::PObject::Driver::file>

=head1 AUTHOR

Sherzod Ruzmetov <sherzodr@cpan.org>

=cut

