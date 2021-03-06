package App::SetScreensaverTimeout;

our $DATE = '2015-01-08'; # DATE
our $VERSION = '0.08'; # VERSION

use 5.010001;
use strict;
use warnings;

use Desktop::Detect qw(detect_desktop);
use File::Slurp::Tiny qw(read_file write_file);
use Proc::Find qw(proc_exists);

our %SPEC;

$SPEC{':package'} = {
    v => 1.1,
    summary => 'Set screensaver timeout',
};

sub _get_or_set {
    my ($which, $mins) = @_;

    my $detres = detect_desktop();

    local $Proc::Find::CACHE = 1;
    if (proc_exists(name=>"gnome-screensaver")) {
        if ($which eq 'set') {
            my $secs = $mins*60;
            system "gsettings", "set", "org.gnome.desktop.session",
                "idle-delay", $secs;
            return [500, "gsettings set failed: $!"] if $?;
        }
        my $res = `gsettings get org.gnome.desktop.session idle-delay`;
        return [500, "gsettings get failed: $!"] if $?;
        $res =~ /^uint32\s+(\d+)$/
            or return [500, "Can't parse gsettings get output"];
        my $val = $1/60;
        return [200, "OK", ($which eq 'set' ? undef : $val), {
            'func.timeout' => $val,
            'func.screensaver'=>'gnome-screensaver',
        }];
    }

    if (proc_exists(name=>"xscreensaver")) {
        my $path = "$ENV{HOME}/.xscreensaver";
        my $ct = read_file($path);
        if ($which eq 'set') {
            my $hours = int($mins/60);
            $mins -= $hours*60;

            $ct =~ s/^(timeout:\s*)(\S+)/
                sprintf("%s%d:%02d:%02d",$1,$hours,$mins,0)/em
                    or return [500, "Can't subtitute timeout setting in $path"];
            write_file($path, $ct);
            system "killall", "-HUP", "xscreensaver";
            $? == 0 or return [500, "Can't kill -HUP xscreensaver"];
        }
        $ct =~ /^timeout:\s*(\d+):(\d+):(\d+)\s*$/m
            or return [500, "Can't get timeout setting in $path"];
        my $val = ($1*3600+$2*60+$3)/60;
        return [200, "OK", ($which eq 'set' ? undef : $val), {
            'func.timeout' => $val,
            'func.screensaver' => 'xscreensaver',
        }];
    }

    if ($detres->{desktop} eq 'kde-plasma') {
        my $path = "$ENV{HOME}/.kde/share/config/kscreensaverrc";
        my $ct = read_file($path);
        if ($which eq 'set') {
            my $secs = $mins*60;
            $ct =~ s/^(Timeout\s*=\s*)(\S+)/${1}$secs/m
                or return [500, "Can't subtitute Timeout setting in $path"];
            write_file($path, $ct);
        }
        $ct =~ /^Timeout\s*=\s*(\d+)\s*$/m
            or return [500, "Can't get Timeout setting in $path"];
        my $val = $1/60;
        return [200, "OK", ($which eq 'set' ? undef : $val), {
            'func.timeout' => $val,
            'func.screensaver'=>'kde-plasma',
        }];
    }

    [412, "Can't detect screensaver type"];
}

$SPEC{get_screensaver_timeout} = {
    v => 1.1,
    summary => 'Get screensaver timeout (in minutes)',
    description => <<'_',

Provide a common way to get screensaver timeout setting. Support several screen
savers (see `set_screensaver_timeout`).

_
    result => {
        summary => 'Timeout value, in minutes',
        schema  => 'float*',
    },
};
sub get_screensaver_timeout {
    _get_or_set('get');
}

my $to_re = '\A\d+(?:\.\d+)?\s*(mins?|minutes?|h|hours?|seconds?|secs?|s)?\z';

$SPEC{set_screensaver_timeout} = {
    v => 1.1,
    summary => 'Set screensaver timeout',
    description => <<'_',

Provide a common way to quickly set screensaver timeout. Will detect the running
screensaver/desktop environment and set accordingly. Supports xscreensaver,
gnome-screensaver, and KDE screen locker. Support for other screensavers will be
added in the future.

* xscreensaver

  To set timeout for xscreensaver, the program finds this line in
  `~/.xscreensaver`:

      timeout:    0:05:00

  modifies the line, save the file, and HUP the xscreensaver process.

* gnome-screensaver

  To set timeout for gnome-screensaver, the program executes this command:

      gsettings set org.gnome.desktop.session idle-delay 300

* KDE

  To set timeout for the KDE screen locker, the program looks for this line in
  `~/.kde/share/config/kscreensaverrc`:

      Timeout=300

  modifies the line, save the file.

_
    args => {
        timeout => {
            summary => 'Value, default in minutes',
            schema => ['str*', match=>$to_re],
            pos => 0,
            # XXX temporary, for testing. will be placed in
            # Perinci::Sub::Complete eventually
            completion => sub {
                require Complete::Bash::History;
                my %args = @_;
                Complete::Bash::History::complete_cmdline_from_hist();
            },
        },
    },
};
sub set_screensaver_timeout {
    my %args = @_;

    my $to = $args{timeout} or return get_screensaver_timeout();

    $to =~ /$to_re/ or return [400, "Invalid timeout value, must match $to_re"];

    my ($mins) = $to =~ /(\d+(?:\.\d+)?)/;
    if ($to =~ /hour|h/) {
        $mins *= 60;
    } elsif ($to =~ /minutes?|mins?/) {
        # noop
    } elsif ($to =~ /seconds?|secs?|s/) {
        $mins /= 60;
    }

    # kde screen locker only accepts whole minutes
    $mins = int($mins);
    $mins = 1 if $mins < 1;

    _get_or_set('set', $mins);
}

1;
# ABSTRACT: Set screensaver timeout

__END__

=pod

=encoding UTF-8

=head1 NAME

App::SetScreensaverTimeout - Set screensaver timeout

=head1 VERSION

This document describes version 0.08 of App::SetScreensaverTimeout (from Perl distribution App-SetScreensaverTimeout), released on 2015-01-08.

=head1 FUNCTIONS


=head2 get_screensaver_timeout() -> [status, msg, result, meta]

{en_US Get screensaver timeout (in minutes)}.

{en_US 
Provide a common way to get screensaver timeout setting. Support several screen
savers (see C<set_screensaver_timeout>).
}

No arguments.

Returns an enveloped result (an array).

First element (status) is an integer containing HTTP status code
(200 means OK, 4xx caller error, 5xx function error). Second element
(msg) is a string containing error message, or 'OK' if status is
200. Third element (result) is optional, the actual result. Fourth
element (meta) is called result metadata and is optional, a hash
that contains extra information.

Return value: {en_US Timeout value, in minutes} (float)


=head2 set_screensaver_timeout(%args) -> [status, msg, result, meta]

{en_US Set screensaver timeout}.

{en_US 
Provide a common way to quickly set screensaver timeout. Will detect the running
screensaver/desktop environment and set accordingly. Supports xscreensaver,
gnome-screensaver, and KDE screen locker. Support for other screensavers will be
added in the future.

=over

=item * xscreensaver

To set timeout for xscreensaver, the program finds this line in
C<~/.xscreensaver>:

  timeout:    0:05:00

modifies the line, save the file, and HUP the xscreensaver process.

=item * gnome-screensaver

To set timeout for gnome-screensaver, the program executes this command:

  gsettings set org.gnome.desktop.session idle-delay 300

=item * KDE

To set timeout for the KDE screen locker, the program looks for this line in
C<~/.kde/share/config/kscreensaverrc>:

  Timeout=300

modifies the line, save the file.
}

=back

Arguments ('*' denotes required arguments):

=over 4

=item * B<timeout> => I<str>

{en_US Value, default in minutes}.

=back

Returns an enveloped result (an array).

First element (status) is an integer containing HTTP status code
(200 means OK, 4xx caller error, 5xx function error). Second element
(msg) is a string containing error message, or 'OK' if status is
200. Third element (result) is optional, the actual result. Fourth
element (meta) is called result metadata and is optional, a hash
that contains extra information.

Return value:  (any)

=head1 KNOWN BUGS

=over

=item * Sometimes fail to lock on KDE

KDE is supposed to pick up on the changes in
`~/.kde/share/config/kscreensaverrc` immediately, and this is confirmed by
running the dialog `kcmshell4 screensaver`. However, sometimes the change does
not take effect and the screensaver won't trigger even after the timeout has
long passed.

=back

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

This software is copyright (c) 2015 by perlancar@cpan.org.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
