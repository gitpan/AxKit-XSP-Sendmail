# $Id: Sendmail.pm,v 1.7 2001/02/16 22:04:14 matt Exp $

package AxKit::XSP::Sendmail;
use strict;
use Apache::AxKit::Language::XSP;
use Mail::Sendmail;
use Email::Valid;
use Carp;

use vars qw/@ISA $NS $VERSION $ForwardXSPExpr/;

@ISA = ('Apache::AxKit::Language::XSP');
$NS = 'http://axkit.org/NS/xsp/sendmail/v1';

$VERSION = "1.0";

## Taglib subs

# send mail
sub send_mail {
    my ($document, $parent, $mailer_args) = @_;
    my $address_errors;

    foreach my $addr_type ('To', 'Cc', 'Bcc') {
        if ($mailer_args->{$addr_type}) {
            foreach my $addr (@{$mailer_args->{$addr_type}}) {
                next if Email::Valid->address($addr);
                $address_errors .=  "Address $addr in '$addr_type' element failed $Email::Valid::Details check. ";
            }
            $mailer_args->{$addr_type}  = join (', ', @{$mailer_args->{$addr_type}});
        }
    }

    # we want a bad "from" header to be caught as a user error so we'll trap it here.
    $mailer_args->{From} ||= $Mail::Sendmail::mailcfg{from};

    unless ( Email::Valid->address($mailer_args->{From}) ) { 
        $address_errors .= "Address '$mailer_args->{From}' in 'From' element failed $Email::Valid::Details check. ";
    }

    if ($address_errors) {
        croak "Invalid Email Address(es): $address_errors";
    }

    # all addresses okay? if so, send.
    
    sendmail( %{$mailer_args} ) || croak $Mail::Sendmail::error;
}

## Parser subs
        
sub parse_start {
    my ($e, $tag, %attribs) = @_; 
    #warn "Checking: $tag\n";

    if ($tag eq 'send-mail') {
        return qq| {# start mail code\n | .
                q| my (%mail_args, @to_addrs, @cc_addrs, @bcc_addrs);| . qq|\n|;
    }
    elsif ($tag eq 'to') {
        return q| push (@to_addrs, ''|;
    }
    elsif ($tag eq 'cc') {
        return q| push (@cc_addrs, ''|;
    }
    elsif ($tag eq 'bcc') {
        return q| push (@bcc_addrs, ''|;
    }
    elsif ($tag =~ /^(subject|message|from)$/) {
        return qq| \$mail_args{'$tag'} = "" |;
    }
    elsif ($tag eq 'smtphost') {
        return q| $mail_args{'smtp'} = "" |;
    }
    else {
        die "Unknown sendmail tag: $tag";
    }
}

sub parse_char {
    my ($e, $text) = @_;
    my $element_name = $e->current_element();


    unless ($element_name eq 'body') {
        $text =~ s/^\s*//;
        $text =~ s/\s*$//;
    }

    return '' unless $text;

    return qq| . '$text' |;
}


sub parse_end {
    my ($e, $tag) = @_;

    if ($tag eq 'send-mail') {
        return <<'EOF';
AxKit::XSP::Sendmail::send_mail(
    $document, $parent,
    {
        %mail_args,
        To => \@to_addrs, 
        Cc => \@cc_addrs, 
        Bcc => \@bcc_addrs,
    },
    );
} # end mail code
EOF
    }
    elsif ($tag =~ /to|bcc|cc/) {
        return ");\n";
    }
    return ";";
}

sub parse_comment {
    # compat only
}

sub parse_final {
   # compat only
}

1;
                
__END__

=head1 NAME

AxKit::XSP::Sendmail - Simple SMTP mailer tag library for AxKit eXtesible Server Pages.

=head1 SYNOPSIS

Add the sendmail: namespace to your XSP C<<xsp:page>> tag:

    <xsp:page
         language="Perl"
         xmlns:xsp="http://apache.org/xsp/core/v1"
         xmlns:sendmail="http://axkit.org/NS/xsp/sendmail/v1"
    >

And add this taglib to AxKit (via httpd.conf or .htaccess):

    AxAddXSPTaglib AxKit::XSP::Sendmail

=head1 DESCRIPTION

The XSP sendmail: taglib adds a simple SMTP mailer to XSP via Milivoj
Ivkovic's platform-neutral Mail::Sendmail module. In addition, all
email addresses are validated before sending using Maurice Aubrey's
Email::Valid package. This taglib is identical to the Cocoon taglib
of the same name, albeit in a different namespace..

=head1 Tag Reference

=head2 C<<sendmail:send-mail>>

This is the required 'wrapper' element for the sendmail taglib branch.

=head2 C<<sendmail:smtphost>>

The this element sets the outgoing SMTP server for the current message.
If ommitted, the default set in Mail::Sendmail's %mailcfg hash will be
used instead. 

=head2 C<<sendmail:from>>

Defines the 'From' field in the outgoing message. If ommited, this
field defaults to value set in Mail::Sendmail's %mailcfg hash. Run
C<perldoc Mall:Sendmail> for more detail.

=head2 C<<sendmail:to>>

Defines a 'To' field in the outgoing message. Multiple instances are
allowed.

=head2 C<<sendmail:cc>>

Defines a 'Cc' field in the outgoing message. Multiple instances are
allowed.

=head2 C<<sendmail:bcc>>

Defines a 'Bcc' field in the outgoing message. Multiple instances are
allowed.

=head2 C<<sendmail:body>>

Defines the body of the outgoing message.

=head1 EXAMPLE

my $mail_message = 'I'm a victim of circumstance!';

  <sendmail:send-mail>
    <sendmail:from>curly@localhost</sendmail:from>
    <sendmail:to>moe@spreadout.org</sendmail:to>
    <sendmail:cc>larry@porcupine.com</sendmail:cc>
    <sendmail:bcc>shemp@alsoran.net</sendmail:cc>
    <sendmail:body><xsp:expr>$mail_message</xsp:expr></sendmail:body>
  </sendmail:send-mail>

=head1 ERRORS

When sending email fails, or an address is invalid, this taglib will
throw an exception, which you can catch with the AxKit exceptions
taglib.

=head1 AUTHOR

Kip Hampton, khampton@totalcinema.com

=head1 COPYRIGHT

Copyright (c) 2001 Kip Hampton. All rights reserved. This program is
free software; you can redistribute it and/or modify it under the same
terms as Perl itself.

=head1 SEE ALSO

AxKit, Mail::Sendmail, Email::Valid

=cut
