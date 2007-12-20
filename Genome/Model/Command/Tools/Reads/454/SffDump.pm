package Genome::Model::Command::Tools::Reads::454::SffDump;

use strict;
use warnings;

use above "Genome";
use Command;
use GSC;
use SFFDump;
use IO::File;
use File::Path;
use File::Basename;

UR::Object::Type->define(
    class_name => __PACKAGE__,
    is => 'Command',
    has => [                                # Specify the command's properties (parameters) <--- 
        'sample'   => { type => 'String',  doc => "sample name"},
        'dir'   => { type => 'String',  doc => "output directory", is_optional => 1},
        'separate'   => { type => 'Boolean',  doc => "keep files separate--don't combine", is_optional => 1}
    ], 
);

sub help_brief {
    "add reads (dump sff 454 reads) and (by default) combine"
}

sub help_detail {                           # This is what the user will see with --help <---
    return <<EOS 
add reads (dump sff 454 reads) and (by default) combine
EOS
}

#sub create {                               # Rarely implemented.  Initialize things before execute <---
#    my $class = shift;
#    my %params = @_;
#    my $self = $class->SUPER::create(%params);
#    # ..do initialization here
#    return $self;
#}

#sub validate_params {                      # Pre-execute checking.  Not requiried <---
#    my $self = shift;
#    return unless $self->SUPER::validate_params(@_);
#    # ..do real checks here
#    return 1;
#}

sub execute {
    my $self = shift;
		my($sample, $dir, $separate) = 
				 ($self->sample, $self->dir, $self->separate);
		$dir ||= 'sff';
		return unless ( defined($sample) && defined($dir)
									);

		$dir =~ s/ \/ $ //x;					# Remove any trailing slash

		# Make sure the output directory exists
		unless (-e $dir) {
			mkpath $dir;
		}

		my $d = SFFDump->new(
												 incoming_dna_name => $sample,
												 output_directory  => $dir,
												 callback => sub { my $f = shift; print "$f\n"; }
												);
		$d->go;

		my @sff_files = glob($dir . '/*.sff');
		my $individual_sff = join(' ',@sff_files);
		unless ($separate) {
			system("sfffile -o $dir/$sample.sff $individual_sff");
		}
}

1;


