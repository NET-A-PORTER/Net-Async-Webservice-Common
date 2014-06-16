package Net::Async::Webservice::Common::Moo::Types;
use strict;
use warnings;
use Type::Library
    -base,
    -declare => qw( AsyncUserAgent SyncUserAgent
                    HTTPRequest
              );
use Type::Utils -all;
use namespace::autoclean;

=head2 C<AsyncUserAgent>

Duck type, any object with a C<do_request>, C<GET> and C<POST>
methods.  Coerced from L</UserAgent> via
L<Net::Async::Webservice::Common::Moo::SyncAgentWrapper>.

=head2 C<UserAgent>

Duck type, any object with a C<request>, C<get> and C<post> methods.

=cut

duck_type AsyncUserAgent, [qw(POST do_request)];
duck_type UserAgent, [qw(post request)];

coerce AsyncUserAgent, from UserAgent, via {
    require Net::Async::Webservice::Common::Moo::SyncAgentWrapper;
    Net::Async::Webservice::Common::Moo::SyncAgentWrapper->new({ua=>$_});
};

class_type HTTPRequest, { class => 'HTTP::Request' };

1;
