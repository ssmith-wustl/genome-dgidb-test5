package Genome::Model::Tools::PooledBac::MapContigsToAssembly;

use strict;
use warnings;

use Genome;
use GSC::IO::Assembly::Ace::Reader;
use IO::File;
use Genome::Utility::FileSystem;

class Genome::Model::Tools::PooledBac::MapContigsToAssembly {
    is => 'Command',
    has => 
    [ 
        ref_sequence => 
        {
            type => 'String',
            is_optional => 0,
            doc => "File pointing to ref seq locations",
        },
        pooled_bac_dir =>
        {
            type => 'String',
            is_optional => 0,
            doc => "Pooled BAC Assembly Directory",    
        },    
        pooled_bac_ace_file => 
        {
            type => 'String',
            is_optional => 1,
            doc => "ace file containing pooled bac sequences"
        },
        pooled_bac_fasta_file =>
        {
            type => 'String',
            is_optional => 1,
            doc => "fasta file containing pooled bac sequences"        
        },
        project_dir =>
        {
            type => 'String',
            is_optional => 0,
            doc => "output directory for pooled bac projects"        
        },
        show_errors =>    
        {
            type => 'flag',
            is_optional => 1,
            doc => "display errors and information messages as blast is run",        
        }       
    ]    
};

sub help_brief {
    "The first step of creating Pooled BAC Projects Maps Contigs to a known reference sequence"
}

sub help_synopsis { 
    return;
}
sub help_detail {
    return <<EOS 
    Blasts Pooled BAC contigs against a known reference assembly.
EOS
}

############################################################
sub execute { 
    my $self = shift;
    $DB::single = 1;
    
    my $ref_sequence = $self->ref_sequence;
    my $pooled_bac_dir = $self->pooled_bac_dir;
    my $project_dir = $self->project_dir;
    $self->error_message("Error creating directory $project_dir") unless Genome::Utility::FileSystem->create_directory($project_dir);
    
    my $ace_file = ''; 
    my $fasta_file = '';
    chdir($self->pooled_bac_dir);
    #build db file
    #input that gets converted to query fasta file
    $ace_file = $self->pooled_bac_dir.'/consed/edit_dir/'.$self->pooled_bac_ace_file if($self->pooled_bac_ace_file); 
    #if a pooled bac fasta file is provided, we use it instead of creating fasta from the ace file above
    $fasta_file = $self->project_dir.'/'.$self->pooled_bac_fasta_file if($self->pooled_bac_fasta_file); 
    $self->error_message("Need either an ace file or pooled bac fasta file to be specified.\n") unless (-e $ace_file || -e $fasta_file);
    my $ref_fasta_file =$self->project_dir.'/ref_seq.fasta';
    #build fasta containing reference sequence regions to be blasted against
    $self->build_fasta_file($self->ref_sequence) if(!(-e $ref_fasta_file&&-e "$ref_fasta_file.qual"));
    
    chdir($project_dir);
    Genome::Model::Tools::WuBlast::Xdformat::Create->execute(
        database => 'bac_region_db', 
        fasta_files => [$self->project_dir.'/ref_seq.fasta'],
    ); 
    #build query file
    my $query_fasta_file = $self->project_dir.'/pooled_contigs.fasta';
    if(-e $ace_file )
    {   
        $self->ace2fasta($ace_file,$query_fasta_file);
    }
    else
    {
        system("cp $fasta_file $query_fasta_file");
    }
    my $params = 'M=1 N=-3 R=3 Q=3 W=30 wordmask=seg lcmask hspsepsmax=1000 golmax=0 B=1 V=1 topcomboN=1';
    $params .= ' -errors -notes -warnings -cpus 4 2>/dev/null' unless ($self->show_errors);
    
    Genome::Model::Tools::WuBlast::Blastn->execute(
        database => 'bac_region_db',
        query_file => $query_fasta_file,
        params => $params,
    );
        
    return 1;
}

sub parse_ref_seq_coords_file
{
    my ($self) = @_;
    my $ref_coords_file = $self->ref_sequence;
    $self->error_message("$ref_coords_file does not exist") unless -e $ref_coords_file;
    my $fh = IO::File->new($ref_coords_file);
    $self->error_message("Error opening $ref_coords_file.") unless defined $fh;
    
    my %ref_seq_coords;
    my $name;
    my $line;
    while ($line = $fh->getline)
    {
        chomp $line;
        last if($line =~ /^\>/);
        next unless length($line);
        next if($line=~/^\#/);
        next if($line=~/^\s*$/);
        my ($token, $data) = $line =~ /(.*)\:\s*(.*)/;print $line,"\n";
        $ref_seq_coords{$token} = $data;
        
    }
    
    my $bac_name;
    do
    {
        if(!($line =~ /^\>/))
        {
            chomp $line;
            my %hash;@hash{ 'chromosome','start','end'} = split /\s+/, $line;
            $ref_seq_coords{$bac_name} = \%hash;
        }
        else
        {
            chomp $line;
            ($bac_name) = $line =~ /\>\s*(.*)/;
        }    
    } while ($line = $fh->getline);
    
    return \%ref_seq_coords;
}

sub ace2fasta
{
    my ($self,$infile, $outfile) = @_;

    my $infh = IO::File->new($infile);
    $self->error_message("Error opening $infile.") unless defined $infile;
    my $outfh = IO::File->new(">$outfile");
    $self->error_message("Error opening $outfile.") unless defined $outfh;
    my $reader = GSC::IO::Assembly::Ace::Reader->new($infh);
    $self->error_message("Error creating ace reader for $infile.") unless defined $reader;
    while(my $line = $infh->getline)
    {
        if($line =~ /^CO/)
        {
            $infh->seek(-length($line),1);
            my $item = $reader->next_object;    
            if($item->{type} eq 'contig')
            {
                $outfh->print(">",$item->{name},"\n");
                $item->{consensus} =~ tr/Xx/Nn/;
                $item->{consensus} =~ s/\*//g;

                $outfh->print($item->{consensus},"\n");
            }
        }
    }
}

sub get_seq
{
    my ($self, $ref_seq_dir,$bac_name, $chromosome, $ref_start, $ref_stop) = @_;
    my $ref_seq_fasta = $ref_seq_dir."/$chromosome.fasta";
    my $fh = IO::File->new($ref_seq_fasta);
    $self->error_message("Error opening $ref_seq_fasta") unless defined $fh;
    my $line = <$fh>;
    my $seq_string;
    while(my $line = <$fh>)
    {
        chomp $line;
        $seq_string .= $line;
    }
    return substr($seq_string, $ref_start, $ref_stop-$ref_start+1);    
}
sub write_fasta
{
    my ($self, $fh, $qfh,$ref_seq_dir, $bac_name, $chromosome, $ref_start, $ref_stop) = @_;
    my $bac_sequence = $self->get_seq($ref_seq_dir,$bac_name, $chromosome,$ref_start,$ref_stop);
    $fh->print(">$bac_name\n");
    $fh->print("$bac_sequence\n");
    $qfh->print(">$bac_name\n");
    my $qual_string;
    for(my $i=0;$i<length($bac_sequence);$i++)
    {
        $qual_string.="37 ";
    }
    $qual_string.="\n";
    $qfh->print($qual_string);
}

sub build_fasta_file
{
    my ($self, $ref_seq_coords_file) = @_;
    my $data = $self->parse_ref_seq_coords_file;
    
    my $ref_seq_fasta = $self->project_dir.'/ref_seq.fasta';
    my $ref_seq_dir = delete $data->{REFERENCE_ASSEMBLY};
    
    my $fh = IO::File->new(">$ref_seq_fasta");
    $self->error_message("Failed to open $ref_seq_fasta for writing.") unless defined $fh;
    my $qfh = IO::File->new(">$ref_seq_fasta.qual");
    $self->error_message("Failed to open $ref_seq_fasta.qual for writing.") unless defined $qfh;
    
    foreach my $bac_name (keys %{$data})
    {
        my ($chromosome, $ref_start, $ref_stop) =  map {  $data->{$bac_name}{$_} } ('chromosome','start','end');#@{{$data}->{$bac_name}};
        $self->write_fasta($fh,$qfh,$ref_seq_dir,$bac_name,$chromosome, $ref_start, $ref_stop);
    }
}


1;
