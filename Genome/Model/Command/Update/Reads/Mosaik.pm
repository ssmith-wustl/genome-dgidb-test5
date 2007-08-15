package Genome::Model::Command::Update::Reads::Mosaik;

use strict;
use warnings;

use UR;
use Command;
use File::Path;

UR::Object::Class->define(
    class_name => __PACKAGE__,
    is => 'Command',
    has => [                                # Specify the command's properties (parameters) <--- 
        'sample'   => { type => 'String',  doc => "sample name"},
        'dir'   => { type => 'String',  doc => "mosaik sequence (output) directory"},
        'bindir'   => { type => 'String',  doc => "directory for binary executables for mosaik", is_optional => 1}
    ], 
);

sub help_brief {
    "add reads to Mosaik"
}

sub help_detail {                           # This is what the user will see with --help <---
    return <<EOS 
add reads to Mosaik
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
		my($sample, $dir, $bindir) = 
				 ($self->sample, $self->dir, $self->bindir);
		$bindir ||= '/gscmnt/sata114/info/medseq/pkg/bin64';
		return unless ( defined($sample) && defined($dir)
									);
		my $mosaik_build ||= "$bindir/MosaikBuild";
		my $fasta2bas ||= "$bindir/fasta2Bas";

		$dir =~ s/ \/ $ //x;					# Remove any trailing slash

		# Make sure the output directory exists
		unless (-e $dir) {
			mkpath $dir;
		}

		system("cd $dir ; $mosaik_build -seq $sample.fasta -qual $sample.fasta.qual -out $sample.dat");
		system("cd $dir ; $fasta2bas --fastaDna $sample.fasta --fastaQual $sample.fasta.qual --bas $sample.bas");
}

1;


