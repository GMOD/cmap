package Bio::GMOD::CMap;
# vim: set ft=perl:

# $Id: CMap.pm,v 1.44 2004-02-10 22:32:54 kycl4rk Exp $

=head1 NAME

Bio::GMOD::CMap.pm - base object for comparative maps

=head1 SYNOPSIS

  package Bio::GMOD::CMap::Foo;
  use Bio::GMOD::CMap;
  use base 'Bio::GMOD::CMap';

  sub foo { print "foo\n" }

  1;

=head1 DESCRIPTION

This is the base class for all the comparative maps modules.  It is
itself based on Andy Wardley's Class::Base module.

=head1 METHODS

=cut

use strict;
use vars '$VERSION';
$VERSION = '0.10';

use Data::Dumper;
use Class::Base;
use Config::General;
use Bio::GMOD::CMap::Data;
use Bio::GMOD::CMap::Constants;
use DBI;
use File::Path;
use Template;

use base 'Class::Base';

# ----------------------------------------------------
sub init {
    my ( $self, $config ) = @_;
    $self->data_source( $config->{'data_source'} ) or return;
    return $self;
}

# ----------------------------------------------------
sub cache_dir {

=pod

=head2 cache_dir

Returns the cache directory.

=cut

    my $self = shift;

    unless ( defined $self->{'cache_dir'} ) {
        my $cache_dir = $self->config('cache_dir');
        unless ( -d $cache_dir ) {
            eval { mkpath( $cache_dir, 0, 0700 ) };
            if ( my $err = $@ ) {
                return $self->error(
                    "Cache directory '$cache_dir' can't be created: $err"
                );
            }
        }

        $self->{'cache_dir'} = $cache_dir;
    }

    return $self->{'cache_dir'};
}

# ----------------------------------------------------
sub config {

=pod

=head2 config

Returns one or all options from the config file.

=cut

    my ( $self, $option ) = @_;

    unless ( $self->{'config'} ) {
        my $conf          = Config::General->new( CONFIG_FILE ) or
            return $self->error('Error reading config file: '.CONFIG_FILE);
        my %config        = $conf->getall or 
            $self->error('No configuration options');
        $self->{'config'} = \%config;
    }

    if ( $option ) {
        my $value = defined $self->{'config'}{ $option } 
            ? $self->{'config'}{ $option } 
            : DEFAULT->{ $option }
        ;

        if ( $value ) {
            return wantarray && ref $value ? @$value : $value;
        }
        else {
            return wantarray ? () : '';
        }
    }
    else {
        return wantarray ? @{ $self->{'config'} } : $self->{'config'};
    }
}

# ----------------------------------------------------
sub data_source {

=pod

=head2 data_source

Remembers what has been selected as the current data source.

=cut

    my $self = shift;
    my $arg  = shift || '';

    #
    # If passed a new data source, force a reconnect.
    #
    if ( $arg ) {
        my %valid_ds = map { $_->{'name'}, 1 } @{ $self->data_sources };
        return $self->error("'$arg' is not a defined data source") 
            unless $valid_ds{ $arg };
        $self->{'data_source'} = $arg;
        $self->{'data_sources'} = undef;
        if ( defined $self->{'db'} ) {
            my $db = $self->db;
            $db->disconnect;
            $self->{'db'} = undef;
        }
    }

    unless ( $self->{'data_source'} ) {
        my @data_sources = @{ $self->data_sources } or return;
        for my $ds ( @data_sources ) {
            $self->{'data_source'} = $ds->{'name'} if $ds->{'is_current'};
        }
    }

    return $self->{'data_source'} || '';
}

# ----------------------------------------------------
sub data_sources {

=pod

=head2 data_sources

Returns all the data souces defined in the configuration file.

=cut

    my ( $self, %args ) = @_;

    unless ( defined $self->{'data_sources'} ) {
        my $config  = $self->config('database') or 
            return $self->error('No database configuration options defined');
        $config     = [ $config ] unless ref $config eq 'ARRAY';

        my $ok = 0;
        if ( my $current = $self->{'data_source'} ) {
            for my $source ( @$config ) {
                if ( $current && $source->{'name'} eq $current ) {
                    $source->{'is_current'} = 1;
                    $ok                     = 1;
                }
                else {
                    $source->{'is_current'} = 0;
                }
            }
        }

        unless ( $ok ) {
            for my $source ( @$config ) {
                if ( $source->{'is_default'} ) {
                    $source->{'is_current'} = 1;
                    $ok                     = 1;
                }
            }
        }

        #
        # If there's only one defined, just use it.
        #
        if ( !$ok && scalar @$config == 1 ) {
            $config->[0]->{'is_current'} = 1;
        }
        else {
            return $self->error('No default data source defined') unless $ok;
        }

        $self->{'data_sources'} = [
            sort { $a->{'name'} cmp $b->{'name'} }
            @$config
        ];

    } 

    if ( @{ $self->{'data_sources'} } ) {
        return $self->{'data_sources'};
    }
    else {
        return $self->error("Can't determine data sources (undefined?)");
    }
}

# ----------------------------------------------------
sub db {

=pod

=head2 db

Returns a database handle.  This is the only way into the database.

=cut

    my $self    = shift;
    my $db_name = shift || $self->data_source;
    return unless $db_name;

    unless ( defined $self->{'db'} ) {
        my $config = $self->config('database') or 
            return $self->error('No database configuration options defined');

        #
        # If more than one datasource is defined, try to find either
        # the one named $db_name or the default one.  Give up if neither.
        #
        my $db_config;
        if ( ref $config eq 'ARRAY' ) {
            my $default;
            for my $section ( @$config ) {
                $default = $section if $section->{'is_default'}; 
                if ( $db_name && $section->{'name'} eq $db_name ) {
                    $db_config = $section;
                    last;
                } 
            }
            $db_config = $default unless defined $db_config;
        }
        elsif ( ref $config eq 'HASH' ) {
            $db_config = $config;
        }
        else {
            return $self->error('DB config not array or hash');
        }

        return $self->error("Couldn't determine database info") unless 
            defined $db_config;

        my $datasource = $db_config->{'datasource'}
            or $self->error('No database source defined');
        my $user       = $db_config->{'user'}
            or $self->error('No database user defined');
        my $password   = $db_config->{'password'} || '';
        my $options    = {
            AutoCommit       => 1,
            FetchHashKeyName => 'NAME_lc',
            LongReadLen      => 3000,
            LongTruncOk      => 1,
            RaiseError       => 1,
        };

        eval {
            $self->{'db'} = DBI->connect( 
                $datasource, $user, $password, $options 
            );
        };

        if ( $@ || !defined $self->{'db'} ) {
            my $error = $@ || $DBI::errstr;
            return $self->error( 
                "Can't connect to data source '$db_name': $error" 
            );
        }
    }

    return $self->{'db'};
}

# ----------------------------------------------------
sub data_module {

=pod

=head2 data

Returns a handle to the data module.

=cut

    my $self = shift;

    unless ( $self->{'data_module'} ) { 
        $self->{'data_module'} = Bio::GMOD::CMap::Data->new(
            data_source => $self->data_source,
        ) or $self->error( Bio::GMOD::CMap::Data->error );
    }

    return $self->{'data_module'};
}

# ----------------------------------------------------
sub get_attributes {

=pod

=head2 get_attributes 

Retrieves the attributes attached to a database object.

=cut

    my $self       = shift;
    my $table_name = shift or return;
    my $object_id  = shift or return;
    my $order_by   = shift || 'display_order,attribute_name';
    my $db         = $self->db or return;
    if ( !$order_by || $order_by eq 'display_order' ) {
        $order_by  = 'display_order,attribute_name';
    }

    return $db->selectall_arrayref(
        qq[
            select   attribute_id,
                     object_id,
                     table_name,
                     display_order,
                     is_public,
                     attribute_name,
                     attribute_value
            from     cmap_attribute
            where    object_id=?
            and      table_name=?
            order by $order_by
        ],
        { Columns => {} },
        ( $object_id, $table_name )
    );
}

# ----------------------------------------------------
sub get_xrefs {

=pod

=head2 get_xrefs 

Retrieves the xrefs attached to a database object.

=cut

    my $self       = shift;
    my $table_name = shift or return;
    my $object_id  = shift or return;
    my $order_by   = shift || 'display_order,xref_name';
    my $db         = $self->db or return;
    if ( !$order_by || $order_by eq 'display_order' ) {
        $order_by  = 'display_order,xref_name';
    }

    return $db->selectall_arrayref(
        qq[
            select   xref_id,
                     object_id,
                     table_name,
                     display_order,
                     xref_name,
                     xref_url
            from     cmap_xref
            where    object_id=?
            and      table_name=?
            order by $order_by
        ],
        { Columns => {} },
        ( $object_id, $table_name )
    );
}

# ----------------------------------------------------
sub get_multiple_xrefs {

=pod

=head2 get_xrefs

Given a table name and some objects, get the cross-references.

=cut

    my ( $self, %args ) = @_;
    my $table_name      = $args{'table_name'} or return;
    my $objects         = $args{'objects'};
    my $db              = $self->db or return;

    return unless @{ $objects || [] };

    my $xrefs = $db->selectall_arrayref(
        q[
            select   object_id, display_order, xref_name, xref_url
            from     cmap_xref
            where    table_name=?
            order by object_id, display_order, xref_name
        ],
        { Columns => {} },
        ( $table_name )
    );

    my ( %xref_specific, @xref_generic );
    for my $xref ( @$xrefs ) {
        if ( $xref->{'object_id'} ) {
            push @{ $xref_specific{ $xref->{'object_id'} } }, $xref;
        }
        else {
            push @xref_generic, $xref;
        }
    }

    my $t = $self->template;
    for my $o ( @$objects ) {
        for my $attr ( @{ $o->{'attributes'} || [] } ) {
            my $attr_val  =  $attr->{'attribute_value'}   or next;
            my $attr_name =  lc $attr->{'attribute_name'} or next;
               $attr_name =~ tr/ /_/s;
            push @{ $o->{'attribute'}{ $attr_name } }, 
                $attr->{'attribute_value'};
        }

        my @xrefs = @{ $xref_specific{ $o->{'object_id'} } || [] };
        push @xrefs, @xref_generic;

        my @processed;
        for my $xref ( @xrefs ) {
            my $url;
            $t->process( \$xref->{'xref_url'}, { object => $o }, \$url );

            push @processed, { 
                xref_name => $xref->{'xref_name'},
                xref_url  => $_,
            } for map { $_ || () } split /\s+/, $url;
        }

        $o->{'xrefs'} = \@processed;
    }
}

# ----------------------------------------------------
sub DESTROY {

=pod

=head2 DESTROY

Object clean-up when destroyed by Perl.

=cut

    my $self = shift;
    $self->db->disconnect if defined $self->{'db'};
    return 1;
}

# ----------------------------------------------------
sub template { 

=pod

=head2 template

Returns a Template Toolkit object.

=cut

    my $self = shift;

    unless ( $self->{'template'} ) {
        my $cache_dir    = $self->cache_dir or return;
        my $template_dir = $self->config('template_dir') || '';
        return $self->error("Template directory '$template_dir' doesn't exist")
            unless -d $template_dir;

        $self->{'template'} = Template->new( 
            COMPILE_EXT     => '.ttc',
            COMPILE_DIR     => $cache_dir,
            INCLUDE_PATH    => $template_dir,
            FILTERS         => {
                dump        => sub { Dumper( shift() ) },
                nbsp        => sub { my $s=shift; $s =~ s{\s+}{\&nbsp;}g; $s },
                commify     => \&Bio::GMOD::CMap::Utils::commify,
            },
        ) or $self->error(
            "Couldn't create Template object: ".Template->error()
        );
    }

    return $self->{'template'};
}

# ----------------------------------------------------
sub warn {

=pod

=head2 warn

Provides a simple way to print messages to STDERR.  Also, I could
easily turn off warnings glabally with the "debug" flag.

=cut

    my $self = shift;
    print STDERR @_;
}

1;

# ----------------------------------------------------
# To create a little flower is the labour of ages.
# William Blake
# ----------------------------------------------------

=pod

=head1 SEE ALSO

L<perl>, L<Class::Base>.

=head1 AUTHOR

Ken Y. Clark E<lt>kclark@cshl.orgE<gt>

=head1 COPYRIGHT

Copyright (c) 2002-3 Cold Spring Harbor Laboratory

This library is free software;  you can redistribute it and/or modify 
it under the same terms as Perl itself.

=cut
