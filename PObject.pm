package Class::PObject;

# $Id: PObject.pm,v 1.10 2003/06/20 06:34:39 sherzodr Exp $

use strict;
use Carp;
use diagnostics;
use vars ('$VERSION', '@ISA', '@EXPORT', '@EXPORT_OK');
require Exporter;

@ISA        = ('Exporter');
@EXPORT     = ('pobject');
@EXPORT_OK  = ('struct');

($VERSION)  = '1.8';

# Preloaded methods go here.


*pobject    = \&struct;

sub struct {
  my ($class, $props);

  # are we given explicit class name to be created in?
  if ( @_ == 2 ) {
    ($class, $props) = @_;
  }
  # Is class name assumed to be the current caller's package?
  elsif ( $_[0] && (ref($_[0]) eq 'HASH') ) {
    $props = $_[0];
    $class = (caller())[0];
  }
  # otherwise, we throw a usage exception:
  else {
    croak "Usage error";
  }

  # should we make sure that current package is not 'main'?
  if ( $class eq 'main' ) {
    croak "class 'main' cannot be the class name";
  }

  # creating the class virtually. Note, that it is different
  # then the way Class::Struct works.
  {
    no strict 'refs';
    # if the properties have already been created, it means the user
    # tried to create the class with the same name twice. He should be shot!
    if ( ${ "$class\::props" } ) {
      croak "are you trying to create the same class two times?";
    }

    # we should have some columns
    unless ( @{$props->{columns}} ) {
      croak "class $class should have columns!";
    }

    # one of the columns should be 'id'. I believe this is a limitation,
    # which should be eliminated in next release
    my $has_id = 0;
    for ( @{$props->{columns}} ) {
      $has_id = $_ eq 'id' and last;
    }
    unless ( $has_id ) {
      croak "'id' column is required! Read 'TODO' section of the manual for more details";
    }
     
    # if no driver was specifiied, default driver to be used is 'file'
    $props->{driver} ||= 'file';
    
    ${ "$class\::props" }   = $props;
    *{ "$class\::new" }     = \&Class::PObject::Template::new;
    *{ "$class\::columns" } = sub { return $_[0]->{columns} };

    # installing 'properties' accessor method. It returned all the properties
    # if the class (everything passed to struct()
    #*{ "$class\::properties" } = sub {
    #      no strict 'refs';
    #      return ${ (ref($_[0]) || $_[0]) . '::props' };
    #    };

    # installing all remaining accessor method for manipulating columns
    for my $colname ( @{$props->{columns}} ) {
      # if the method with the same name is already present in
      # caller's package, we should let them override us
      $class->can($colname) && next;
      *{ "$class\::$colname" } = sub {
          $_[1] ? ($_[0]->{columns}->{$colname} = $_[1]) :
                  return $_[0]->{columns}->{$colname}
        }
    }    
    *{ "$class\::load" }        = \&Class::PObject::Template::load;
    *{ "$class\::save" }        = \&Class::PObject::Template::save;
    *{ "$class\::remove" }      = \&Class::PObject::Template::remove;
    *{ "$class\::remove_all" }  = \&Class::PObject::Template::remove_all;
    *{ "$class\::error" } = sub {
          no strict 'refs';
          if ( defined $_[1] ) {
            ${ (ref($_[0]) || $_[0]) . '::ERROR'} = $_[1];
          }
          return ${ (ref($_[0]) || $_[0]) . '::ERROR'};
        };
    
    *{ "$class\::dump" } = sub {
          require Data::Dumper;
          my $d = Data::Dumper->new([$_[0]], [ref $_[0]]);
          $d->Indent($_[1]);
          $d->Deepcopy(1);
          $d->Dump
        }
  }
}




# templates for newly created class
package Class::PObject::Template;
use Carp;

sub new {
  my $class = shift;
  $class    = ref($class) || $class;

  # What should be do if we detect odd number of arguments?
  # I'd say we should croak() right away. We don't want to
  # end-up with corrupted record in the database, whether the
  # code checks for error messages, or not!
  if ( @_ % 2 ) {
    croak "Odd number of arguments passed to new(). May result in corrupted data";
  }

  my $props_sub = sub {
    no strict 'refs';
    return ${ "$class\::props" }
  };

  my $props = $props_sub->();

  # object properties as represented internally by Class::PObject.
  # Please, don't use this information from within your codes. This
  # change in subsequent releases
  my $self = {
      columns     => { },
      driver      => $props->{driver},
      datasource  => $props->{datasource} || undef,
  };
  
  # DBD::CVS seems to keep all the column names in uppercase. This is a problem,
  # when the load() method calls new() with key/value pairs while creating an object
  # off the disk. So we first convert the @_ to a hashref
  my $args = { @_ };
  # and fill in 'columns' attribute of the class with lower-cased names:
  while ( my ($k, $v) = each %$args ) {
    $self->{columns}->{lc $k} = $v;
  }

  # It's possible that new() was not given all the column/values. So we
  # detect the ones missing, and assign them 'undef'
  for my $colname ( @{$props->{columns}} ) {
    $self->{columns}->{$colname} ||= undef;
  }
  
  # I'm not sure if 'datasource' should be mandatory. I'm open to
  # any suggestions. Some drivers may be able to recover 'datasource' on the fly,
  # without asking for expclicit definition. I'm open to suggestions
  unless ( defined $self->{datasource} ) {
    #$class->error("'datasource' is required");
    #return undef;
  }

  # we may also check if the driver is indeed a valid one. However doing so
  # does not allow creating in-memory objects without valid driver. So let's leave 
  # this test for related methods.
  
  # returning the object!
  return bless($self, $class);
}




sub save {
  my $self  = shift;
  my $class = ref($self) || $self;

  my $props_sub = sub {
    no strict 'refs';
    return ${ "$class\::props" }
  };

  my $props = $props_sub->();
  my $pm = "Class::PObject::Driver::" . $props->{driver};

  # closure for getting and setting driver object
  my $get_set_driver = sub {
    no strict 'refs';
    if ( defined $_[0] ) {
      ${ "$pm\::OBJECT" } = $_[0];
    }
    return ${ "$pm\::OBJECT" };
  };

  # if the driver object is still available, we should use it
  # instead of creating another object. For DBI-related drivers,
  # creating new objects may be costly
  my $driver_obj = $get_set_driver->();
  unless ( defined $driver_obj ) {
    eval "require $pm";
    if ( $@ ) {
      $self->error("couldn't load $pm: " . $@);
      return undef;
    }
    $driver_obj = $pm->new();
    unless ( defined $driver_obj ) {
      $self->error("couldn't create '$pm' object: " . $pm->error);
      return undef;
    }
    # we cache the driver object now so it will be available later
    $get_set_driver->($driver_obj);
  }

  # we now call the driver's save() method, with the name of the class,
  # all the props passed to struct(), and column values to be stored
  my $rv = $driver_obj->save($class, $props, $self->{columns});
  unless ( defined $rv ) {
    $self->error($driver_obj->error);
    return undef;
  }
  return $rv;
}






sub load {
  my $self = shift;
  my $class = ref($self) || $self;

  # closure for getting the class properties
  my $props_sub = sub {
    no strict 'refs';
    return ${ "$class\::props" }
  };

  my $props = $props_sub->();
  my $pm = "Class::PObject::Driver::" . $props->{driver};

  # closure for getting and setting driver object
  my $get_set_driver = sub {
    no strict 'refs';
    if ( defined $_[0] ) {
      ${ "$pm\::OBJECT" } = $_[0];
    }
    return ${ "$pm\::OBJECT" };
  };

  my $driver_obj = $get_set_driver->();
  unless ( defined $driver_obj ) {
    eval "require $pm";
    if ( $@ ) {
      $self->error("couldn't load $pm: " . $@);
      return undef;
    }
    $driver_obj = $pm->new();
    unless ( defined $driver_obj ) {
      $self->error($pm->error);
      return undef;
    }
    $get_set_driver->($driver_obj);
  }

  # if we are not called in context where array value is expected,
  # we optimize our query by defining 'limit'
  unless ( wantarray() ) {
    $_[1]->{limit} = 1;
  }
  
  my $rows = $driver_obj->load($class, $props, @_) or return;
  unless ( scalar @$rows ) {
    $self->error( $driver_obj->error );
    return ();
  }

  # if calle din array context, we return an array of objects:
  if (  wantarray() ) {
    return (map { $self->new(%$_) } @$rows);
  }

  # if we come this far, we're being called in scalar context
  return $self->new( %{ $rows->[0] } );
}



sub remove {
  my $self = shift;
  my $class = ref($self);

  unless ( ref($self) ) {
    croak "remove() used as a static method";
  }

  my $props_sub = sub {
    no strict 'refs';
    return ${ ref($self) . '::props' }
  };

  my $props = $props_sub->();
  my $pm    = "Class::PObject::Driver::" . $props->{driver};

  # closure for getting and setting driver object
  my $get_set_driver = sub {
    no strict 'refs';
    if ( defined $_[0] ) {
      ${ "$pm\::OBJECT" } = $_[0];
    }
    return ${ "$pm\::OBJECT" };
  };

  my $driver_obj = $get_set_driver->();
  # if the driver object doesn't already exist, it either means this object
  # hasn't been flushed into disk yet, so remove() doesn't make sense, or
  # the driver object was lost somewhere. I believe it is a more serious
  # problem, so we just have to croak()
  unless ( defined $driver_obj ) {
    croak "driver object is missing";
  }

  # if 'id' field is missing, most likely it's because this particular object
  # hasn't been saved into disk yet
  unless ( defined $self->id) {
    croak "object is not saved into disk yet";
  }

  my $rv = $driver_obj->remove($class, $props, $self->id);
  unless ( defined $rv ) {
    $self->error($driver_obj->error);
    return undef;
  }
  return $rv;
}








sub remove_all {
  my $self = shift;
  my $class = ref($self) || $self;

  my $props_sub = sub {
    no strict 'refs';
    return ${ (ref($self) || $self) . '::props' }
  };

  my $props = $props_sub->();
  my $pm = "Class::PObject::Driver::" . $props->{driver};

  # closure for getting and setting driver object
  my $get_set_driver = sub {
    no strict 'refs';
    if ( defined $_[0] ) {
      ${ "$pm\::OBJECT" } = $_[0];
    }
    return ${ "$pm\::OBJECT" };
  };

  my $driver_obj = $get_set_driver->();

  unless ( defined $driver_obj ) {
    eval "require $pm";
    if ( $@ ) {
      die "couldn't load $pm: " . $@;
    }
    $driver_obj = $pm->new();
    unless ( defined $driver_obj ) {
      $self->error($pm->error);
      return undef;
    }
    $get_set_driver->($driver_obj);
  }

  # if remove_all() is supported, we better call it
  # otherwise try to deal with it on our own
  if ( $driver_obj->UNIVERSAL::can('remove_all') ) {
    my $rv = $driver_obj->remove_all($class, $props);
    unless ( defined $rv ) {
      $self->error($driver_obj->error());
      return undef;
    }
    return 1;
  }

  for ( @{$driver_obj->load($class, $props)} ) {
    my $dataobj = $self->new(%$_);
    unless($dataobj->remove()) {
      $self->error($_->error);
      return undef;
    }
  }
  return 1;
}








1;
__END__
# Below is stub documentation for your module. You better edit it!

=head1 NAME

Class::PObject - Perl extension for programming persistent objects

=head1 SYNOPSIS

We can create a person object with:

  use Class::PObject

  pobject Person => {
    columns => ['id', 'name', 'email'],
    datasource => 'data/person'
  };

Or even:

  package Person;

  pobject {
    columns => ['id', 'name', 'email''
    datasource => 'data/person'
  };

We can now use the above Person class:

  my $person = new Person();

  $person->name('Sherzod');
  $person->email('sherzodr@cpan.org');

  my $new_id = $person->save();

We can access the saved Person later, make necessary changes and save back:

  $person = Person->load($new_id);
  $person->name('Sherzod Ruzmetov (The Geek)');

  $person->save();

We can load all the previously stored objects:

  my @people = Person->load();
  for ( my $i=0; $i < @people; $i++ ) {
    my $person = $people[$i];
    printf("[%02d] %s <%s>\n", $person->id, $person->name, $person->email);
  }

or we can load all the objects based on some criteria and sort the list by column name in descending order,
and limit the results to only the first 3 objects:

  my @people = Person->load({name=>"Sherzod"}, {sort=>'name', direction=>'desc', limit=>3});

We can also retrieve records incrementally:

  my @people = Person->load(undef, {offset=>10, limit=>10});

=head1 WARNING

This is 'alpha' release. I mainly want to hear some ideas, criticism and suggestions from people.
Look at TODO section for more details.

=head1 DESCRIPTION

Class::PObject is a class framework for creating persistent objects. Such objects can store themselves
into disk, and recreate themselves from the disk.

If it is easier for you, just think of a persistent object as a single record of a relational database:

  +-----+----------------+--------+----------+
  | id  | title          | artist | album_id |
  +-----+----------------+--------+----------+
  | 217 | Yagonam O'zing | Sevara |        1 |
  +-----+----------------+--------+----------+

The above record of a song can be represented as a persistent object. Using Class::PObject, you can defined this
object like this:

  pobject Song => {
    columns => ['id', 'title', 'artist', 'album_id']
  };

  my $song = new Song(title=>"Yagonam O'zing", artist=>"Sevara", album_id=>1);

All the disk access is performed through its drivers, thus allowing your objects truly transparent database
access. Currently supported drivers are 'mysql', 'file' and 'csv'. More drivers can be added, and I believe will be added.

=head1 PROGRAMMING STYLE

The style of Class::PObject is very similar to that of L<Class::Struct>. Instead of exporting 'struct()', however,  Class::PObject exports 'pobject()'. Another visual difference is the way you define your arguments. In Class::PObject, each property of the class is represented as one column.

=head2 DEFINING OBJECTS

Object can be created in several ways. You can create the object in its own .pm file with the following syntax:

  package Article;

  pobject {
    columns => ['id', 'title', 'date', 'author', 'source', 'text']
  };


Or you can also create an in-line object - from within your programs with more explicit declaration:

  pobject Article => {
    columns => ['id', 'title', 'date', 'author', 'source', 'text']
  };

Effect of the above two examples is identical - Article object. By default, Class::PObject will fall back to 'file' driver if you do not specify any drivers. So the above Article object could also be redefined more explicitly as:

  pobject Article => {
    columns => \@columns,
    driver => 'file'
  };

The above examples are creating temporary objects. These are the ones stored in your system's temporary location. So if you want more 'permanent' objects, you should also declare its datasource:

  pobject Article => {
    columns => \@columns,
    datasource => 'data/articles'
  };

Now, the above article object will store its objects into data/articles folder. Since data storage is so dependant on the drivers, we'll leave it for library drivers.

Class declarations are tightly dependant to the type of driver being used, so we'll leave the rest of the declaration to specific drivers. In this document, we'll concentrate more on the user interface of the Class::PObject - something not dependant on the driver.

=head2 CREATING NEW OBJECTS

After you define an object, as described above, now you can create instances of those objects. Objects are created with new() - constructor method. To create an instance of the above Article object, we do:

  $article = new Article();

The above syntax will create an empty Article object. We can now fill 'columns' of this object one by one:

  $article->title("Persistent Objects with Class::PObject");
  $article->date("Sunday, June 08, 2003"),
  $article->author("Sherzod B. Ruzmetov");
  $article->source("lost+found (http://author.handalak.com)");
  $article->text("CONTENTS OF THE ARTICLE GOES HERE");


Another way of filling in objects, is by passing column values to the constructor - new():

  $article = new Article(title  =>  "Persistent Objects with Class::PObject",
                         date   =>  "Sunday, June 08, 2003",
                         author =>  "Sherzod Ruzmetov",
                         source =>  "lost+found (http://author.handalak.com" );

  $article->text("CONTENTS OF THE ARTICLE GO HERE");

Notice, above example is initializing all the properties of the object except for 'text' in the constructor,
and initializing 'text' separately. You can use any combination, as long as you are satisfied.

=head2 STORING OBJECTS

Usually, when you create the objects and fill them with data, they are in-memory data structures, and not
attached to any disk device. It's when you call save() method of those objects when they become so. To store
the above article into disk:

  $article->save();

save() method returns newly created object id on success, undef on failure. So you may want to check its
return value to see if it succeeded:

  my $new_id = $article->save() or die "couldn't store the article";

Note: we'll talk more about handling exceptions in later sections.

=head2 LOADING OBJECTS

No point of storing stuff if you can't retrieve them when you want. Class::PObject objects support load() method which allows you do that. You can retrieve objects in many ways. The easiest, and the most efficient way of loading an object from the disk is by its id:

  my $article = Article->load(1251);

the above code is retrieving an article with id 1251. You can now either display the article on your web page:

  printf("<h1>%s</h1>",  $article->title);
  printf("<div>By %s</div>", $article->author);
  printf("<div>Posted on %s</div>", $article->date);
  printf("<p>%s</p>", $article->text);

or you can make some changes, say, change its title and save it back:

  $article->title("Persistent Objects in Perl made easy with Class::PObject");
  $article->save();

Other ways of loading objects can be by passing column values, in which case the object will retrieve all the objects from the database matching your search criteria:

  my @articles = Article->load({author=>"Sherzod Ruzmetov"});

The above code will retrieve all the articles from the database written by "Sherzod Ruzmetov". You can specify more criteria to narrow your search down:

  my @articles = Article->load({author=>"Sherzod Ruzmetov", source=>"lost+found"});

The above will retrieve all the articles written by "Sherzod Ruzmetov" and with source "lost+found". We can of course, pass no arguments to load(), in which  case all the objects of the same type will be returned.

Elements of returned @array are instances of Article objects. We can generate the list of all the articles with the following syntax:

  my @articles = Article->load();
  for my $article ( @articles ) {
    printf("[%02d] - %s - %s - %s\n", $article->id, $article->title, $article->author, $article->date);
  }

load() also supports second set of arguments used to do post-result filtering. Using these sets you can sort the results by any column, retrieve first n number of results, or do incremental retrievals. For example, to retrieve first 10 articles with the highest rating (assuming our Article object supports 'rating' property):

  my @favorites = Article->load(undef, {sort=>'rating', direction=>'desc', limit=>10});

The above code is applying descending ordering on rating column, and limiting the search for first 10 objects. We could also do incremental retrievals. This method is best suited for web applications, where you can present "previous/next" navigation links and limit each listing to some number:

  my @articles = Article->load(undef, {offset=>10, limit=>10});

Above code retrieves records 10 through 20.

=head2 REMOVING OBJECTS

Objects created by Class::PObject support method called "remove()" and "remove_all()". "remove()" is an object method, can used only to remove one object at a time. "remove_all()" removes all the objects of the same type, thus a little more scarier.

Note, that all the objects can still be removed with  "remove()" method, without any need for more explicit "remove_all()". So why two methods? On some drivers, removing all the objects at once is more efficient than removing objects one by one. Perfect example is 'mysql' driver.

To remove an article with id 1201, we first need to create the object of that article by loading it:

  # we first need to load the article:
  my $article = Article->load(1201);
  $article->remove();

remove() will return any true value indicating success, undef on failure.

  $article->remove() or die "couldn't remove the article";

remove_all(), on the other hand, is a static class method:

  Article->remove_all();


=head2 DEFINING METHODS OTHER THAN ACCESSORS

If you are defining the object in its own class file, you can extend the class with custom
methods. For example, assume you have a User object, which needs to be authenticated before
they can access certain parts of the web site. It may be a good idea to add "authenticate()" method
into your User class, which either returns the User object if he/she is logged in properly, or returns
undef.

  package User;

  pobject {
    columns     => ['id', 'login', 'psswd', 'email'],
    datasource  => 'data/users'
  };

  sub authenticate {
    my $class = shift;
    my ($cgi, $session) = @_;

    # if the user is already logged in, return the object:
    if ( $session->param('_logged_in') ) {
      return $class->load({id=>$session->param('_logged_in')});
    }

    # if we come this far, we'll try to initialize the object with CGI parameters:
    my $login     = $cgi->param('login')    or return undef;
    my $password  = $cgi->param('password') or return undef;

    # if we come this far, both 'login' and 'password' fields were submitted in the form:
    my $user = $class->load({login=>$login, psswd=>$password});

    # if the user could be loadded, we set the session parameter to his/her id
    if ( defined $user ) {
      $session->param('_logged_in', $user->id);
    }
    return $user;
  }

Now, we can check if the user is logged into our web site with the following code:

  use User;

  my $user = User->authenticate($cgi, $session);
  unless ( defined $user ) {
    die "You need to login to the website before you can access this page!";
  }

  printf("<h2>Hello %s</h2>", $user->login);

Notice, we're passing CGI and CGI::Session objects to authenticate. You can do it differently depending
on the tools you're using.

=head2 ERROR HANDLING

Objects created with Class::PObject tries never to die(), and lets the programer to decide what to do on failure, (unless of course, you insult it with wrong syntax).

Methods that may fail are the one to do with disk access, namely, save(), load(), remove() and remove_all(). So it's advised that you check these methods' return values before you assume any success. If an error occurs, the above methods will return undef. More verbose error message will be accessible through error() method. In addition, save() method should always return the object id, either newly created, or updated.

  my $new_id = $article->save();
  unless ( defined $new_id ) {
    die "couldn't save the article: " . $article->error();
  }

  Article->remove_all() or die "couldn't remove objects:" . Article->error;

=head1 MISCELLANEOUS METHODS

In addition to the above described methods, objects of Class::PObject also support the following
few useful ones:

=over 4

=item * 

columns() - returns hash-reference to all the columns of the object. Keys of the hash hold colum names,
and their values hold respective column values:

  my $columns = $article->columns();
  while ( my ($k, $v) = each %$columns ) {
    printf("%s => %s\n", $k, $v);
  }

=item *

dump() - dumps the object as a chunk of visually formatted data structures using standard L<Data::Dumper>.
This method is mainly for debugging, and I believe will be present only untill stable release of the library
is launched.

=item *

error() - class method. Returns the error message from last I/O operations, if any. This error message
is also available through $CLASS::ERROR global variable:

  $article->save() or die $article->error();
  # or
  $article->save() or  die $Article::ERROR;

=item *

struct() - another alias for pobject(). Initial release of the library used to export struct(). Since it may clash with standar Class::Struct's struct(), I decided to make it available ONLY at request:

  use Class::PObject 'struct';

  struct Article => {
    columns \@columns,
  };

=back

=head1 TODO

Following are the lists of features and/or fixes that need to be applied before considering
the library ready for production environment. The list is not exhaustive. Feel free to add your
suggestions.

=head2 TEST, TEST AND TEST

The library should be tested more.

=head2 DRIVER SPECS

Currently driver specifications are not very well documented. Need to spend more time to come up
with more intuitive and comprehensive specification.

=head2 MORE FLEXIBLE LOAD()

load() will not be all we need until it supports at least simple joins. Something similar to the
following may do:

  @articles = Article->load(join => ['ObjectName', \%terms, \%args]);

I believe it's something to be supported by object drivers, that's where it can be performed more efficiently.

=head2 GLOBAL DESCTRUCTOR

Class::PObjects try to cache the driver object for more extended periods than current object's scope permits them
to. So a "global" DESTROY should be applied to prevent memory leaks or other unfavorable consequences, especially under persistent environments, such as mod_perl or GUI environments.

At this point, I don't have how to implement it the best way.

=head1 DRIVER SPECS NOTES

L<Class::PObject::Driver>

=head1 DEVELOPER NOTES

coming soon...

=head1 SEE ALSO

L<Class::PObject>, L<Class::PObject::Driver::mysql>,
L<Class::PObject::Driver::file>

=head1 AUTHOR

Sherzod Ruzmetov <sherzod@cpan.org>

=cut
