package Genome::Model::Command::AddReads::454::Mosaik;

use strict;
use warnings;

use UR;
use Command;
use Genome::Model::Command::AddReads::Mosaik;
use IO::File;
use File::Path;
use File::Basename;

UR::Object::Class->define(
    class_name => __PACKAGE__,
    is => 'Command',
    has => [                                # Specify the command's properties (parameters) <--- 
        'sample'   => { type => 'String',  doc => "sample name"},
        'sffdir'   => { type => 'String',  doc => "sff (input) directory--default is sff", is_optional => 1},
        'dir'   => { type => 'String',  doc => "mosaik sequence (output) directory"},
        'bindir'   => { type => 'String',  doc => "directory for binary executables for mosaik", is_optional => 1}
    ], 
);

sub help_brief {
    "add reads (454 reads) to Mosaik"
}

sub help_detail {                           # This is what the user will see with --help <---
    return <<EOS 
add reads (454 reads) to Mosaik
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
		my($sample, $sffdir, $dir, $bindir) = 
				 ($self->sample, $self->sffdir, $self->dir, $self->bindir);
		$sffdir ||= 'sff';
		$bindir ||= '/gscmnt/sata114/info/medseq/pkg/bin64';
		return unless ( defined($sample) && defined($dir)
									);

		my $pyrobayes = "$bindir/PyroBayes";
		$dir =~ s/ \/ $ //x;					# Remove any trailing slash

		# Make sure the output directory exists
		unless (-e $dir) {
			mkpath $dir;
		}

		system("$pyrobayes	-i $sffdir/$sample.sff -o $dir/$sample");

		my $mosaik = Genome::Model::Command::AddReads::Mosaik->create(
																															sample => $sample,
																															dir => $dir);
		$mosaik->execute();
}

1;


