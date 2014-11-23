package App::SetScreensaverTimeout;

our $DATE = '2014-11-23'; # DATE
our $VERSION = '0.01'; # VERSION

use 5.010001;
use strict;
use warnings;

use Desktop::Detect qw(detect_desktop);
use File::Slurp::Tiny qw(read_file write_file);
use Proc::Find qw(proc_exists);

our %SPEC;

$SPEC{set_screensaver_timeout} = {
    v => 1.1,
    summary => 'Set screensaver timeout',
    description => <<'_',

Provide a common way to quickly set screensaver timeout from command-line.
Support xscreensaver, gnome-screensaver, and KDE screen locker. Support for
other screensavers will be added in the future.

_
    args => {
        timeout => {
            summary => 'Value, default in minutes',
            schema => ['str*', match=>'\A\d+(?:\.\d+)?\s*(mins?|minutes?|h|hours?)?\z'],
            req => 1,
            pos => 0,
        },
    },
};

sub set_screensaver_timeout {
    my %args = @_;

    my ($mins) = $args{timeout} =~ /(\d+(?:\.\d+)?)/;
    if ($args{timeout} =~ /h/) {
        $mins *= 60;
    }
    # kde screen locker only accepts whole minutes
    $mins = int($mins);
    $mins = 1 if $mins < 1;

    my $detres = detect_desktop();

    if ($detres->{desktop} eq 'kde') {
        my $path = "$ENV{HOME}/.kde/share/config/kscreensaverrc";
        my $ct = read_file($path);
        my $secs = $mins*60;
        $ct =~ s/^(Timeout\s*=\s*)(\S+)/${1}$secs/m
            or return [500, "Can't subtitute Timeout value in $path"];
        write_file($path, $ct);
        return [200];
    }

    local $Proc::Find::CACHE = 1;
    if (proc_exists(name=>"gnome-screensaver")) {
        my $secs = $mins*60;
        system "gsettings", "set", "org.gnome.desktop.session", "idle-delay",
            $secs;
        return [500, "gsettings failed: $!"] if $?;
        return [200];
    }

    if (proc_exists(name=>"xscreensaver")) {
        my $path = "$ENV{HOME}/.xscreensaver";
        my $ct = read_file($path);
        my $hours = int($mins/60);
        $mins -= $hours*60;

        $ct =~ s/^(timeout:\s*)(\S+)/
            sprintf("%s%d:%02d:%02d",$1,$hours,$mins,0)/em
                or return [500, "Can't subtitute timeout value in $path"];
        write_file($path, $ct);
        system "killall", "-HUP", "xscreensaver";
        $? == 0 or return [500, "Can't kill -HUP xscreensaver"];
        return [200];
    }

    [412, "Can't detect screensaver type"];
}

1;
# ABSTRACT: Set screensaver timeout

__END__

=pod

=encoding UTF-8

=head1 NAME

App::SetScreensaverTimeout - Set screensaver timeout

=head1 VERSION

This document describes version 0.01 of App::SetScreensaverTimeout (from Perl distribution App-SetScreensaverTimeout), released on 2014-11-23.

=head1 FUNCTIONS


=head2 set_screensaver_timeout(%args) -> [status, msg, result, meta]

Set screensaver timeout.

Provide a common way to quickly set screensaver timeout from command-line.
Support xscreensaver, gnome-screensaver, and KDE screen locker. Support for
other screensavers will be added in the future.

Arguments ('*' denotes required arguments):

=over 4

=item * B<timeout>* => I<str>

Value, default in minutes.

=back

Return value:

Returns an enveloped result (an array).

First element (status) is an integer containing HTTP status code
(200 means OK, 4xx caller error, 5xx function error). Second element
(msg) is a string containing error message, or 'OK' if status is
200. Third element (result) is optional, the actual result. Fourth
element (meta) is called result metadata and is optional, a hash
that contains extra information.

 (any)

=head1 HOMEPAGE

Please visit the project's homepage at L<https://metacpan.org/release/App-SetScreensaverTimeout>.

=head1 SOURCE

Source repository is at L<https://github.com/perlancar/perl-App-SetScreensaverTimeout>.

=head1 BUGS

Please report any bugs or feature requests on the bugtracker website L<https://rt.cpan.org/Public/Dist/Display.html?Name=App-SetScreensaverTimeout>

When submitting a bug or request, please include a test-file or a
patch to an existing test-file that illustrates the bug or desired
feature.

=head1 AUTHOR

perlancar <perlancar@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2014 by perlancar@cpan.org.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
