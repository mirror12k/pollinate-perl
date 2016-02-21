#!/usr/bin/env perl
package Pollinate;
use parent 'LWP::UserAgent';
use strict;
use warnings;

use feature 'say';

use Digest::SHA 'sha512_hex';
use Data::Entropy 'entropy_source';
use IO::File;



# a basic implementation of a pollinate client using LWP::UserAgent as a base
# can be executed on command line with a url to a pollen server and an optional random string


sub new {
	my $class = shift;
	my %args = @_;

	$args{agent} //= 'pollinate-perl/0.1';
	my $self = $class->SUPER::new(%args);

	return $self
}


sub gen_weak_entropy {
	join '', map rand, 1 .. 100
}

sub gen_strong_entropy {
	entropy_source->get_bits(8 * 64);
}


sub gen_pollen {
	my ($self) = @_;
	return $self->gen_weak_entropy . $self->gen_strong_entropy;
}


sub pollinate {
	my ($self, $url, $pollen) = @_;

	my $challenge = sha512_hex ($pollen // $self->gen_pollen);
	my $res = $self->post($url, Content => "challenge=$challenge");

	if ($res->is_success) {
		return (split "\n", $res->content)[1]
	} else {
		warn "request failed: ", $res->content;
		return
	}
}


sub main {
	my ($url, $challenge) = @_;

	die "pollen server url required" unless defined $url;

	my $ua = Pollinate->new;
	my $entropy = $ua->pollinate($url, $challenge);

	if (defined $entropy) {
		say "got entropy: $entropy";
		# write the entropy to the entropy pool
		my $file = IO::File->new('/dev/urandom', O_WRONLY|O_APPEND);
		$file->print($entropy);
		$file->close;
	} else {
		say "request failed";
	}
}

caller or main(@ARGV)
