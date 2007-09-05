package NT::Barcode;
use strict;

BEGIN{
    use English;
    use SerialPortHandler;
}

my $buffer = '';


$::TMP_CFG = (-d 'c:\\temp' ? 'c:\\temp\\tmp.cfg' : 'tmp.cfg');

#-------------- constructor ---------------------
sub new{
    my $class = shift;
    my $OS_NAME = shift;
    my $PORT = shift;
    my $self = {};
    bless $self, $class;
    $self->initSerialPort($OS_NAME,$PORT);
    $self;
}

sub close{
    my $self = shift;
    $self->{PORT_HDL}->close;
}

#------------- initSerialPort
#   Takes in an optional os name, inits a port, and returns the handle (also saves the handle)
sub initSerialPort {
    my $self = shift;
    my ($OS_NAME, $port) = @_;
    $OS_NAME ||= ($ENV{'OSTYPE'} ? $ENV{'OSTYPE'} : 'MSWin32'); 
    $self->{PORT_HDL} = SerialPortHandler::OpenPort($OS_NAME, $port);
    $self->{PORT_HDL};
}


#------------- checkForBC
#   Takes a reference to the subroutine to call if the barcode is found
#   This function probably should be repeated often
sub checkForBC{
    my $self = shift;
    my ($callback) = @_;
    #Set to dummy character to avoid warnings
    my $tmpChar = "D";

    return undef unless defined $self->{PORT_HDL};
    #Read one character at a time from port
   while (sysread($self->{PORT_HDL}, $tmpChar, 1))
    {
        if($tmpChar !~ /\n|\r/)
        {
            $buffer .= $tmpChar;
        }
    }

    #Match on #{......} and take off first occurance
    while(defined $buffer && $buffer =~ s/^\#\{(......)\}//){
        &$callback($1);
    }
}


sub getNewBarcodes{
    my $self = shift;

    #Set to dummy character to avoid warnings
    my $tmpChar = "D";
    
    return () unless defined $self->{PORT_HDL};
    #Read one character at a time from port
    while (sysread($self->{PORT_HDL}, $tmpChar, 1))
    {
        if($tmpChar !~ /\n|\r/)
        {
            $buffer .= $tmpChar;
        }
    }
    #Match on #{......} and take off first occurance
    my @barcodes;
    while(defined $buffer && $buffer =~ s/^(\#\{)?(......|empty)(\})?//){
        push @barcodes, $2;
    }
    return @barcodes;
}

1;
