package Net::Async::Webservice::Common::WithRequestWrapper;
use Moo::Role;
use Types::Standard qw(Object HashRef Str);
use Types::URI qw(Uri);
use Type::Params qw(compile);
use Net::Async::Webservice::Common::Types qw(HTTPRequest);
use Net::Async::Webservice::Common::Exception;
use HTTP::Request;
use Encode;
use namespace::autoclean;
use 5.010;

# ABSTRACT: helper methods to perform HTTP request

=head1 SYNOPSIS

  package My::WS::Client {
   use Moo;
   with 'Net::Async::Webservice::Common::WithUserAgent';
   with 'Net::Async::Webservice::Common::WithRequestWrapper';
  }

  my $loop = IO::Async::Loop->new;
  my $c = My::WS::Client->new({loop=>$loop});
  $c->post('https://api.webservice.whatever/',$content)->then(sub{
    my ($response_body) = @_;
    say "Got <$response_body>";
    return Future->wrap();
  })->get;

=head1 DESCRIPTION

This role provides a few methods to perform HTTP requests via a
C<user_agent> attribute / method (which is required, and could be
provided by L<Net::Async::Webservice::Common::WithUserAgent> or any
other means).

Failures (both during connection, and as signaled by the HTTP response
codes) are wrapped in
L<Net::Async::Webservice::Common::Exception::HTTPError> and returned
as failed futures. On success, the future yields the decoded content
of the response.

=cut

requires 'user_agent';

=attr C<ssl_options>

Optional hashref, its contents will be passed to C<user_agent>'s
C<do_request> method.

=cut

has ssl_options => (
    is => 'lazy',
    isa => HashRef,
);
sub _build_ssl_options {
    # this is to work around an issue with IO::Async::SSL, see
    # https://rt.cpan.org/Ticket/Display.html?id=96474
    eval "require IO::Socket::SSL" or return {};
    return { SSL_verify_mode => IO::Socket::SSL::SSL_VERIFY_PEER() }
}

=method C<request>

  $c->request($http_request) ==> $decoded_content

Performs the given request via the C<user_agent>, with
C<fail_on_error> set; if the request succeeds, the returned future
will yield the decoded content of the response. If the request fails,
the future will fail with a two-element failure: a
L<Net::Async::Webservice::Common::Exception::HTTPError> and the string
C<'webservice'>.

=cut

sub request {
    state $argcheck = compile( Object, HTTPRequest );
    my ($self, $request) = $argcheck->(@_);

    my $response_future = $self->user_agent->do_request(
        request => $request,
        fail_on_error => 1,
        (($request->uri->scheme//'') eq 'https' ? %{ $self->ssl_options // {} } : ()),
    )->transform(
        done => sub {
            my ($response) = @_;
            return $response->decoded_content(
                default_charset => 'utf-8',
                raise_error => 1,
            )
        },
        fail => sub {
            my ($exception,$kind,$response,$req2) = @_;
            return (Net::Async::Webservice::Common::Exception::HTTPError->new({
                request=>($req2//$request),
                response=>$response,
                (($kind//'') ne 'http' ? ( more_info => "@_" ) : ()),
            }),'webservice');
        },
    );
}

=method C<post>

  $c->post($url,$body) ==> $decoded_content

Shortcut to submit a very basic POST request. The C<$body> will be
UTF-8 encoded, no headers are set. Uses L</request> to perform the
actual request.

=cut

sub post {
    state $argcheck = compile( Object, Uri, Str );
    my ($self, $url, $body) = $argcheck->(@_);

    my $request = HTTP::Request->new(
        POST => $url,
        [], encode('utf-8',$body),
    );
    return $self->request($request);
}

=method C<get>

  $c->get($url) ==> $decoded_content

Shortcut to submit a very basic GET request. No headers are set. Uses
L</request> to perform the actual request.

=cut

sub get {
    state $argcheck = compile( Object, Uri );
    my ($self, $url) = $argcheck->(@_);

    my $request = HTTP::Request->new(
        GET => $url,
    );
    return $self->request($request);
}

1;
