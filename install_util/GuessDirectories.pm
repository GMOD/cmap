package GuessDirectories;

# this package never gets installed - it's just used by Build.PL
sub conf {
    if ( $^O =~ /mswin/i ) {    # windows system
        for (
            'C:/Program Files/Apache Group/Apache2/conf',
            'C:/Program Files/Apache Group/Apache/conf',
            'C:/Apache/conf',
            'C:/Apache2/conf'
            )
        {
            return $_ if -d $_;
        }
    }
    else {
        for (
            '/usr/local/apache/conf',     # standard apache install
            '/usr/local/apache2/conf',    # standard apache2 install
            '/etc/httpd/conf',            # RedHat linux
            '/etc/apache',                # Slackware linux
            '/etc/apache2',               # Slackware linux
            '/etc/httpd',                 # MacOSX
            )
        {
            return $_ if -d $_;
        }
    }
    return;
}

sub templates {
    if ( $^O =~ /mswin/i ) {              # windows system
        for (
            [   'C:/Program Files/Apache Group/Apache2/templates',
                'C:/Program Files/Apache Group/Apache2/templates'
            ],
            [   'C:/Program Files/Apache Group/Apache2',
                'C:/Program Files/Apache Group/Apache2/templates'
            ],
            [   'C:/Program Files/Apache Group/Apache/templates',
                'C:/Program Files/Apache Group/Apache/templates'
            ],
            [   'C:/Program Files/Apache Group/Apache',
                'C:/Program Files/Apache Group/Apache/templates'
            ],
            [ 'C:/Apache/templates',  'C:/Apache/templates' ],
            [ 'C:/Apache',            'C:/Apache/templates' ],
            [ 'C:/Apache2/templates', 'C:/Apache2/templates' ],
            [ 'C:/Apache2',           'C:/Apache2/templates' ],
            )
        {
            return $_->[0] if -d $_->[1];
        }
    }
    else {
        for (

            # standard apache install
            [ '/usr/local/apache/templates', '/usr/local/apache/templates' ],
            [ '/usr/local/apache',           '/usr/local/apache/templates' ],

            # standard apache2 install
            [   '/usr/local/apache2/templates',
                '/usr/local/apache2/templates',
            ],
            [ '/usr/local/apache2', '/usr/local/apache2/templates', ],

            # RedHat linux
            [ '/etc/httpd/templates', '/etc/httpd/templates' ],
            [ '/etc/httpd',           '/etc/httpd/templates' ],

            # Slackware linux
            [ '/etc/apache/templates',  '/etc/apache/templates' ],
            [ '/etc/apache',            '/etc/apache/templates' ],
            [ '/etc/apache2/templates', '/etc/apache2/templates' ],
            [ '/etc/apache2',           '/etc/apache2/templates' ],

            # MacOSX
            [ '/etc/httpd/templates', '/etc/httpd/templates' ],
            [ '/etc/httpd',           '/etc/httpd/templates' ],
            )
        {
            return $_->[0] if -d $_->[1];
        }
    }
    return;
}

sub web_document_root {
    if ( $^O =~ /mswin/i ) {    # windows system
        for (
            'C:/Program Files/Apache Group/Apache2/htdocs',
            'C:/Program Files/Apache Group/Apache/htdocs',
            'C:/Apache/htdocs',
            'C:/Apache2/htdocs'
            )
        {
            return $_ if -d $_;
        }
    }
    else {
        for (
            '/usr/local/apache/htdocs',        # standard apache install
            '/usr/local/apache2/htdocs',       # standard apache2 install
            '/var/www/html',                   # RedHat linux
            '/var/www/htdocs',                 # Slackware linux
            '/Library/Webserver/Documents',    # MacOSX
            )
        {
            return $_ if -d $_;
        }
    }
    return;
}

sub cgibin {
    if ( $^O =~ /mswin/i ) {                   # windows system
        for (
            'C:/Program Files/Apache Group/Apache2/cgi-bin',
            'C:/Program Files/Apache Group/Apache/cgi-bin',
            'C:/Apache/cgi-bin',
            'C:/Apache2/cgi-bin'
            )
        {
            return $_ if -d $_;
        }
    }
    else {
        for (
            '/usr/local/apache/cgi-bin',            # standard apache install
            '/usr/local/apache2/cgi-bin',           # standard apache2 install
            '/var/www/cgi-bin',                     # RedHat & Slackware linux
            '/Library/Webserver/CGI-Executables',   # MacOSX
            )
        {
            return $_ if -d $_;
        }
    }
    return;
}

1;

=pod

=head1 SEE ALSO

L<perl>, L<Class::Base>.

=head1 AUTHOR

Taken from GBrowse.

Modified by Ben Faga E<lt>faga@cshl.eduE<gt>.

=head1 COPYRIGHT

Copyright (c) 2007 Cold Spring Harbor Laboratory

This library is free software;  you can redistribute it and/or modify 
it under the same terms as Perl itself.

=cut

