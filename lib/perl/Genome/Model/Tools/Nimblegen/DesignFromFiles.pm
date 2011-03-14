package Genome::Model::Tools::Nimblegen::DesignFromFiles;

use strict;
use warnings;
use Genome::Model::Tools::Nimblegen;
use IO::File;

class Genome::Model::Tools::Nimblegen::DesignFromFiles {
  is => 'Command',
  has => [
  input_file => {
    type => 'String',
    doc => "A file containing the paths to the SNV, Indel, and SV files to create a design for",
  },
  output_file => {
    type => 'String',
    is_optional => 1,
    doc => "The resulting Nimblegen design file. If undefined, only variant counts are shown",
  },
  span => {
    type => 'Integer',
    is_optional => 1,
    default => 200,
    doc => "The number of bases to span the region upstream and downstream of a variant locus",
  },
  ]
};

sub help_brief {
  "Takes a list of SNV, Indel, and SV files and generates a BED file for capture validation";
}

sub help_detail {
  return <<EOS
Takes as input a file containing file paths to SNV, Indel, and SV annotation files (one path per
line) and generates a list of regions to target for capture validation on Nimblegen's Solid Phase
Capture Array. Files in the input list should be classified as "snvs", "indels", or "svs" and
formatted as shown in the sample input file below.

snvs
/gscmnt/sata425/info/PCGP/Somatic/SJRB1-Somatic/build101816068/t1v_tier1_snp.csv
#Files like tier3 sites can be excluded from the design by commenting them out using a '#'
#/gscmnt/sata425/info/PCGP/Somatic/SJRB1-Somatic/build101816068/hc3_tier3_snp_high_confidence.csv

indels
/gscmnt/sata197/info/PCGP/SJRB1/gatk/SJRB1.GATK.somatic.anno.tier1
/gscmnt/sata197/info/PCGP/SJRB1/samtools/t1i_tier1_indel.csv.assembly.somatic.noNT.anno

svs
/gscmnt/sata197/info/PCGP/SV/SJRB1/SJRB1.allchr.Q40.somatic.assembled.HQfiltered.csv
/gscmnt/sata197/info/PCGP/SV/SJRB1/SD.out
EOS
}

sub execute {
  my $self = shift;
  $DB::single = 1;

  my $probe_span = $self->span;
  #All regions in the final BED file will be restricted to those from these chromosomes
  my %valid_chrs = map{ $_ => 1 } (1..22, qw( X Y x y));

  my $file_list = $self->input_file;
  my ( $snv_indel_file, $sv_file ) = ( "$file_list\_snv_indel", "$file_list\_sv" );

  my ( %files, $type );
  my $inFh = IO::File->new( $file_list ) or die "Couldn't open $file_list! $!";
  foreach my $line( $inFh->getlines )
  {
    next if( $line =~ m/^$/ || $line =~ m/^#/ ); #Skip empty lines or comments
    $type = $1 if( $line =~ m/^(snvs|indels|svs)$/ );
    chomp( $line );
    push( @{$files{$type}}, $line ) if( $line =~ m/^\// );
  }
  $inFh->close;

  #Quit if one of the files don't exist
  ( -e $_ ) or die "File doesn't exist: $_" foreach( @{$files{snvs}}, @{$files{indels}}, @{$files{svs}} );
  #warn user if a file is empty
  ( -s $_ ) or warn "File is empty: $_" foreach( @{$files{snvs}}, @{$files{indels}}, @{$files{svs}} );

  #Make sure that the files are formatted properly, and count the variants
  my %var_cnt = ( snvs => 0, indels => 0, svs => 0 );
  foreach my $muttype ( keys %files )
  {
    foreach my $filepath ( @{$files{$muttype}} )
    {
      my $fh = IO::File->new( $filepath );
      while( my $line = $fh->getline )
      {
        next if( $line =~ m/^(#|chromosome_name|Chr\t|readgroup)/ ); #Skip headers
        chomp( $line );

        #This section and the next can be expanded to support new annotation formats
        if( $muttype eq 'snvs' && $line =~ m/^\w+\t\d+\t\d+\t\S\t\S\tSNP/ )
        {
          my ( $chr ) = split( /\t/, $line );
          $chr =~ s/chr//i;
          ++$var_cnt{snvs} if( defined $valid_chrs{$chr} );
        }
        elsif( $muttype eq 'indels' && ( $line =~ m/^\w+\t\d+\t\d+\t[0-]\t\w+/ || $line =~ m/^\w+\t\d+\t\d+\t\w+\t[0-]/) )  #WU and StJude formatting```
        {
          my ( $chr ) = split( /\t/, $line );
          $chr =~ s/chr//i;
          ++$var_cnt{indels} if( defined $valid_chrs{$chr} );
        }
        elsif( $muttype eq 'svs' && $line =~ m/^\w+\.\w+\t\w+\t\d+\t\d+\t\w+\t\d+\t\d+\t(INV|INS|DEL|ITX|CTX)/ ) #BreakDancer output
        {
          my ( undef, $chr1, undef, undef, $chr2 ) = split( /\t/, $line );
          $chr1 =~ s/chr//i; $chr2 =~ s/chr//i;
          ++$var_cnt{svs} if( defined $valid_chrs{$chr1} && defined $valid_chrs{$chr2} );
        }
        elsif( $muttype eq 'svs' && $line =~ m/^\w+\t\d+\t\d+(\+|\-)\t\w+\t\d+\t\d+(\+|\-)\t(INV|INS|DEL|ITX|CTX)/ ) #SquareDancer output
        {
          my ( $chr1, undef, undef, $chr2 ) = split( /\t/, $line );
          $chr1 =~ s/chr//i; $chr2 =~ s/chr//i;
          ++$var_cnt{svs} if( defined $valid_chrs{$chr1} && defined $valid_chrs{$chr2} );
        }
        elsif( $muttype eq 'svs' && $line =~ m/^\w+\t\d+\t\w+\t\d+\t\S\S\t(INV|INS|DEL|ITX|CTX)/ ) #SJ formatting
        {
          my ( $chr1, undef, $chr2 ) = split( /\t/, $line );
          $chr1 =~ s/chr//i; $chr2 =~ s/chr//i;
          ++$var_cnt{svs} if( defined $valid_chrs{$chr1} && defined $valid_chrs{$chr2} );
        }
        else
        {
          die "Unrecognized format in file:\n$filepath!\nThe line tested was:\n\n$line\n";
        }
      }
      $fh->close;
    }
  }

  #If there are too many regions, ask the user to exclude some
  my $total_cnt = $var_cnt{snvs} + $var_cnt{indels} + $var_cnt{svs};
  print "SNVs\tIndels\tSVs\tTotal\n$var_cnt{snvs}\t$var_cnt{indels}\t$var_cnt{svs}\t$total_cnt\n";
  print "Note that two regions are generated from each SV reported above\n";

  #Stop here if user only wanted the total counts, and not the designs
  return 1 unless( defined $self->output_file );

  #Create a combined file of snvs and indels to use with gmt nimblegen design-from-annotation
  my $snindelFh = IO::File->new( $snv_indel_file, ">" );
  foreach my $filepath ( @{$files{snvs}}, @{$files{indels}} )
  {
    my $fh = IO::File->new( $filepath );
    while( my $line = $fh->getline )
    {
      next if( $line =~ m/^(#|chromosome_name|Chr\t)/ ); #Skip headers
      chomp( $line );
      my ( @cols ) = split( /\t/, $line );
      $cols[0] =~ s/chr//i;
      $snindelFh->print( join( "\t", @cols ), "\n" ) if( defined $valid_chrs{$cols[0]} );
    }
    $fh->close;
  }
  $snindelFh->close;
  print "Combined snvs and indels into file $snv_indel_file.\nDesigning array BED file using \"gmt nimblegen design-from-annotation\"...\n";
  my $designSnvIndel = Genome::Model::Tools::Nimblegen::DesignFromAnnotation->create(
    span => $probe_span,
    annotation_file=>$snv_indel_file,
    output_file=>"$snv_indel_file.nimblegen" );
  ( $designSnvIndel->execute ) or die "Error running \"gmt nimblegen design-from-annotation\"!\n";

  #Create a combined file of svs to use with gmt nimblegen design-from-sv
  my $svFh = IO::File->new( $sv_file, ">" );
  foreach my $filepath ( @{$files{svs}} )
  {
    my $fh = IO::File->new( $filepath );
    while( my $line = $fh->getline )
    {
      next if( $line =~ m/^(#|chromosome_name|Chr\t|readgroup)/ ); #Skip headers
      chomp( $line );
      if( $line =~ m/^\w+\.\w+\t\w+\t\d+\t\d+\t\w+\t\d+\t\d+\t(INV|INS|DEL|ITX|CTX)/ ) #BreakDancer output
      {
        my ( undef, $chr1, $outStart, $inStart, $chr2, $inEnd, $outEnd ) = split( /\t/, $line );
        $chr1 =~ s/chr//i; $chr2 =~ s/chr//i;
        $svFh->print( join( ".", $chr1, $outStart, $inStart, $chr2, $inEnd, $outEnd ), "\t$line\n" ) if( defined $valid_chrs{$chr1} && defined $valid_chrs{$chr2} );
      }
      elsif( $line =~ m/^\w+\t\d+\t\d+(\+|\-)\t\w+\t\d+\t\d+(\+|\-)\t(INV|INS|DEL|ITX|CTX)/ ) #SquareDancer output
      {
        my ( $chr1, $start, undef, $chr2, $end ) = split( /\t/, $line );
        $chr1 =~ s/chr//i; $chr2 =~ s/chr//i;
        $svFh->print( join( ".", $chr1, $start, $start, $chr2, $end, $end ), "\t$line\n" ) if( defined $valid_chrs{$chr1} && defined $valid_chrs{$chr2} );
      }
      elsif( $line =~ m/^\w+\t\d+\t\w+\t\d+\t\S\S\t(INV|INS|DEL|ITX|CTX)/ ) #SJ formatting
      {
        my ( $chr1, $start, $chr2, $end ) = split( /\t/, $line );
        $chr1 =~ s/chr//i; $chr2 =~ s/chr//i;
        $svFh->print( join( ".", $chr1, $start, $start, $chr2, $end, $end ), "\t$line\n" ) if( defined $valid_chrs{$chr1} && defined $valid_chrs{$chr2} );
      }
    }
    $fh->close;
  }
  $svFh->close;
  print "Combined svs into file $sv_file.\nDesigning array BED file using \"gmt nimblegen design-from-sv\"...\n";
  my $designSv = Genome::Model::Tools::Nimblegen::DesignFromSv->create(
    span => $probe_span,
    sv_file => $sv_file,
    output_file => "$sv_file.nimblegen" );
  ( $designSv->execute ) or die "Error running \"gmt nimblegen design-from-sv\"!\n";

  #Concatenate the two design files generated to create the final design
  my $outFh = IO::File->new( $self->output_file, ">" );
  my $inFh1 = IO::File->new( "$snv_indel_file.nimblegen" ) or warn "Can't open file $snv_indel_file.nimblegen\n";
  $outFh->print( $_ ) foreach( $inFh1->getlines );
  $inFh1->close;
  my $inFh2 = IO::File->new( "$sv_file.nimblegen" ) or warn "Can't open file $sv_file.nimblegen\n";
  $outFh->print( $_ ) foreach( $inFh2->getlines );
  $inFh2->close;
  $outFh->close;

  print "BED file for Nimblegen is the first 3 columns in " . $self->output_file . "\n";

  return 1;
}

1;
