# $Id: 01_signature.t,v 1.1 2003-09-19 19:05:23 kycl4rk Exp $

use strict;
print "1..1\n";

if ( !eval { require Module::Signature; 1 } ) {
    print "ok 1 # skip - no Module::Signature found\n";
}
elsif ( !eval { require Socket; Socket::inet_aton('pgp.mit.edu') } ) {
    print "ok 1 # skip - Cannot connect to the keyserver";
}
else {
    ( Module::Signature::verify() == Module::Signature::SIGNATURE_OK() )
      or print "not ";
    print "ok 1 # Valid signature\n";
}
