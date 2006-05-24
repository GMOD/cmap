package CMapBuilder;

=head1 NAME

CMapBuilder

=head1 DESCRIPTION

This is the builder/installer module for CMap.  It use Module::Build.

=cut

use strict;
use Cwd;
use CGI;
use File::Basename;
use File::Copy;
use File::Find;
use File::Path;
use File::Spec::Functions;
use Module::Build;
use Pod::Html;

use base 'Module::Build';

# ----------------------------------------------------
sub ACTION_build {
    my $self = shift;
    $self->SUPER::ACTION_build;
}

# ----------------------------------------------------
sub ACTION_install {
    my $self = shift;
    my %args = map { $_, 1 } @{ $self->{'args'}{'ARGV'} || [] };
    $self->ACTION_install_html      unless $args{'nohtml'};
    $self->ACTION_templates unless $args{'notemplates'};

    #
    # Install config file.
    #
    unless ( $args{'noconf'} ) {
        my $conf_dir = $self->notes('CONF');
        unless ( -d $conf_dir ) {
            eval { mkpath( $conf_dir, 0, 0755 ) };
            warn "Can't create conf dir $conf_dir: $@\n" if $@;
        }

        foreach my $conf_file ( 'global.conf', 'example.conf' ) {
            my $from_conf = catfile( 'conf',    $conf_file );
            my $to_conf   = catfile( $conf_dir, $conf_file );
            my $copy_conf = 1;
            if ( -e $to_conf ) {
                $copy_conf = $self->y_n( 
                    "'$to_conf' exists.  Overwrite?", 'n' 
                );
            }

            $self->copy_if_modified(
                from    => $from_conf,
                to      => $to_conf,
                flatten => 0,
            ) if $copy_conf;
        }
    }

    #
    # Install the CGI script.
    #
    my $from_cgi = 'cgi-bin/cmap';
    my $to_cgi = catfile( $self->notes('CGIBIN'), 'cmap' );
    $self->copy_if_modified(
        from    => $from_cgi,
        to      => $to_cgi,
        flatten => 0,
    );
    chmod 0755, $to_cgi or die "Cannot make '$to_cgi' executable: $!\n";

    #
    # Make the temp dir for the images
    #
    my $cache_dir = $self->notes('CACHE');
    unless ( -d $cache_dir ) {
        eval { mkpath( $cache_dir, 0, 0777 ) };
        # mkpath won't give more permissive permissions than the parent
        chmod 0777, $cache_dir or die "Cannot make '$cache_dir' read/write/executable: $!\n";
        warn "Can't create image cache dir $cache_dir: $@\n" if $@;
    }

    #
    # Make the temp dir for the sessions
    #
    my $session_dir = $self->notes('SESSIONS');
    unless ( -d $session_dir ) {
        eval { mkpath( $session_dir, 0, 0777 ) };
        # mkpath won't give more permissive permissions than the parent
        chmod 0777, $session_dir or die "Cannot make '$session_dir' read/write/executable: $!\n";
        warn "Can't create image session dir $session_dir: $@\n" if $@;
    }

    $self->SUPER::ACTION_install;

    chomp( my $host = `hostname` || 'localhost' );
    print join( "\n\n",
        '',
        'CMap has been installed.',
        "Be sure to edit the config files with database info!",
        "Remember to purge the cache with cmap_admin.pl after changing the config file or changing the data.",
        qq[Then go to "http://$host/cmap"], '' );
}

# ----------------------------------------------------
sub ACTION_realclean {
    my $self = shift;
    $self->delete_filetree('cmap_install.conf');
    $self->SUPER::ACTION_realclean;
}

# ----------------------------------------------------
sub ACTION_html {
    my $self = shift;
    my $cwd  = cwd();

    #
    # Turn all POD files into HTML and install into "htdocs."
    #
    my ( @pod_files, @cleanup );
    find(
        sub {
            push @pod_files, $File::Find::name
              if -f $_ && $File::Find::name =~ /\.pod$/;
        },
        $cwd
    );

    #
    # Prepare a list of the base files to include in the default index page.
    #
    my @html_links = (
        [ '/cgi-bin/cmap/viewer', 'CMap Viewer' ],
        [ '/cgi-bin/cmap/admin',  'Web Admin Tool' ],
        [ '/cmap/tutorial/',      'User Tutorial' ],
        [ '/cmap/admintut/',      'Admin Tutorial' ],
    );

    for my $pod (@pod_files) {
        my $filename = basename $pod;
        my $outfile  = $filename;
        $filename =~ s/[_-]/ /g;
        $filename =~ s/\.pod$//;
        $outfile  =~ s/\.pod$/\.html/;
        my $outpath = catfile( $cwd, 'htdocs', $outfile );
        print "pod2html $pod -> $outpath\n";
        pod2html( $pod, "--outfile=$outpath", "--backlink=Back to Top",
            "--title=$filename", "--css=/cmap/pod-style.css", );
        push @html_links, [ $outfile, $filename ];
        push @cleanup, $outpath;
    }

    #
    # Find all the relevant "docs" and install them into "htdocs."
    #
    my @doc_files;
    find(
        sub {
            push @doc_files, $File::Find::name
              if -f $_ && $File::Find::name =~ /\.(png|html)$/;
        },
        'docs'
    );

    for my $file (@doc_files) {
        my $filename = basename $file;
        my $outpath = catfile( $cwd, 'htdocs', $filename );
        print "$file -> $outpath\n";
        copy( $file, $outpath ) unless -e $outpath;
        push @html_links, [ $filename, $filename ];
        push @cleanup, $outpath;
    }

    $self->add_to_cleanup(@cleanup);

    #
    # Create the main CMap index page with a summary of the install.
    #
    my $index = catfile( 'htdocs', 'index.html' );
    open INDEX, ">$index" or die "Can't write new index file '$index': $!\n";
    my $q      = CGI->new;
    my $title  = 'CMap Installation Summary';
    my $navbar = join(
        '&nbsp;|&nbsp;',
        map {
                $_->[1]
              ? $q->a( { -href => $_->[1] }, $_->[0] )
              : $q->b( $_->[0] )
          } (
            [ 'CMap Home'      => '' ],
            [ 'Maps'           => '/cgi-bin/cmap/viewer' ],
            [ 'Map Search'     => '/cgi-bin/cmap/map_search' ],
            [ 'Feature Search' => '/cgi-bin/cmap/feature_search' ],
            [ 'Matrix'         => '/cgi-bin/cmap/matrix' ],
            [ 'Map Sets'       => '/cgi-bin/cmap/map_set_info' ],
            [ 'Feature Types'  => '/cgi-bin/cmap/feature_type_info' ],
            [ 'Map Types'      => '/cgi-bin/cmap/map_type_info' ],
            [ 'Evidence Types' => '/cgi-bin/cmap/evidence_type_info' ],
            [ 'Species'        => '/cgi-bin/cmap/species_info' ],
            [ 'Saved Links'    => '/cgi-bin/cmap/saved_link' ],
            [ 'Help'           => '/cgi-bin/cmap/help' ],
            [ 'Tutorial'       => '/cmap/tutorial' ],
          )
    );

    print "Creating htdocs/index.html\n";
    print INDEX join(
        "\n",
        $q->start_html( { -title => $title, -style => 'cmap.css' } ),
        $q->h1($title),
        $q->br,
        "<!-- Here's a sample navigation bar you may want to use. -->",
        $navbar,
        "<!-- End CMap navbar -->",
        $q->p('Congratulations!  CMap has been installed.'),
        $q->p(
                'Eventually you will want to create your own content '
              . 'for this intro page.'
        ),
        $q->p(
                'Start using CMap with one of the following options.'
        ),
        $q->ul(
            $q->li(
                $q->a( { -href => '/cgi-bin/cmap/viewer' },
                    'Maps' )
                    . " - Use a menu to select your starting maps\n"
            ),
            $q->li(
                $q->a(
                    { -href => '/cgi-bin/cmap/map_search' }, 'Map Search'
                    )
                    . " - If the map set is quite large, the Map Search page can be quicker than sorting through menus.\n"
            ),
            $q->li(
                $q->a( { -href => '/cgi-bin/cmap/feature_search' },
                    'Feature Search' )
                    . " - Search for a specific feature and display it on a map.\n"
            ),
            $q->li(
                $q->a( { -href => '/cgi-bin/cmap/matrix' }, 'Matrix' )
                    . " - View a table of the number of correspondences between pairs of map sets and maps.\n"
            ),
            $q->li(
                $q->a( { -href => '/cgi-bin/cmap/saved_link' },
                    'Saved Links' )
                    . " - View pages previously saved or imported.\n"
            ),
            ),
        $q->p(
            'For an introduction to the basic consepts of CMap, please see the '
                . $q->a( { -href => '/cgi-bin/cmap/help' }, 'help pages' )
                . ' or the '
                . $q->a( { -href => '/cmap/tutorial' }, 'tutorial' )
                . ".\n" ),
        $q->p(
            'We would appreciate you would include an acknowlegement of CMap '
              . 'on this page, e.g.:'
        ),
        $q->p(
            $q->a(
                { -href => 'http://www.gmod.org/cmap' },
                'CMap is free software from the GMOD project'
            )
        ),
        $q->p(
                'For the mean time, here are some links to the installed '
              . 'application and supporting docs:'
        ),
        $q->ul(
            (
                map { $q->li( $q->a( { -href => $_->[0] }, $_->[1] ) ) . "\n" }
                  @html_links
            )
        ),
        'CMap was installed on ' . scalar localtime,
        $q->br,
        $q->a(
            { -href => 'http://www.gmod.org' },
            $q->img(
                {
                    -src => 'gmod_logo.jpg',
                    -alt => 'Powered by GMOD',
                }
            )
        ),
        '<hr>',
        'CMap is part of the <a href="http://www.gmod.org/">GMOD</a> project',
        $q->end_html,
        ''
    );
    close INDEX;
}

# ----------------------------------------------------
sub ACTION_install_html {
    my $self   = shift;
    my $to_dir = $self->notes('HTDOCS');
    my $from   = 'htdocs';
    my @htdocs = $self->read_dir($from);
    for my $file (@htdocs) {
        my $to = $to_dir;
        if ( $file =~ /($from)(.*)/ ) {
            $to = catdir( $to, $2 );
        }

        if ( $file =~ m{htdocs/index\.html$} && -e $to ) {
            next unless $self->y_n( "'$to' exists.  Overwrite?", 'n' );
        }

        $self->copy_if_modified(
            from    => $file,
            to      => $to,
            flatten => 0,
        );
    }
}

# ----------------------------------------------------
sub ACTION_templates {
    my $self      = shift;
    my $to_dir    = $self->notes('TEMPLATES');
    my $from      = 'templates';
    my @templates = $self->read_dir($from);

    for my $file (@templates) {
        my $to = $to_dir;
        if ( $file =~ /($from)(.*)/ ) {
            $to = catdir( $to, $2 );
        }

        $self->copy_if_modified(
            from    => $file,
            to      => $to,
            flatten => 0,
        );
    }
}

# ----------------------------------------------------
sub read_dir {
    my $self = shift;
    my $dir  = shift;
    die "Directory '$dir' does not exist\n" unless -d $dir;

    my @files;
    find(
        sub {
            push @files, $File::Find::name
              if -f $_ && $File::Find::name !~ /CVS/;
        },
        $dir
    );

    return @files;
}

# ----------------------------------------------------

=pod

=head1 AUTHOR

Ken Y. Clark E<lt>kclark@cshl.orgE<gt>.

=head1 COPYRIGHT

Copyright (c) 2004 Cold Spring Harbor Laboratory

This program is free software;  you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;

