!//////////////////////////////////////////////////////////////////////
! PARAMETER DEFINITION FOR GRID
!//////////////////////////////////////////////////////////////////////
MODULE  LAYER_PARAMS
    TYPE LAYER
        INTEGER :: ID                            ! IDENTIFICATION NUMBER OF A GRID LAYER
        INTEGER :: PARENT                        ! ID OF ITS FATHER GRID
        INTEGER :: LEVEL                        ! GRID LEVEL
        CHARACTER(120) :: NAME                            ! FOR FUTURE USE
        CHARACTER(120) :: DEPTH_NAME                    ! FILENAME OF WATERDEPTH DATA

        INTEGER :: FS                            ! OPTION: CONTROLLING FORMAT OF INPUT DATA FILE
        INTEGER*4 :: NX, NY                        ! DIMENSION OF GRIDS IN X AND Y DIRECTIONS
        REAL, DIMENSION(:, :), POINTER :: DEFORM        ! SEAFLOOR DEFORMATION IF FAULT MODEL IS IMPLEMENTED
        REAL, DIMENSION(:, :, :), POINTER :: Z            ! FREE SURFACE ELEVATION
        REAL, DIMENSION(:, :, :), POINTER :: M            ! VOLUME FLUX IN X
        REAL, DIMENSION(:, :, :), POINTER :: N            ! VOLUME FLUX IN Y
        REAL, DIMENSION(:, :), POINTER :: H            ! STILL WATER DEPTH AT T = 0.0
        REAL, DIMENSION(:, :, :), POINTER :: HT            ! TRANSIENT WATER DEPTH AT T = N*DT AND T = (N+1)*DT
        REAL, DIMENSION(:, :), POINTER :: HP            ! STILL WATER DEPTH AT DISCHARGE POINT P (I+1/2,J)
        REAL, DIMENSION(:, :), POINTER :: HQ            ! STILL WATER DEPTH AT DISCHARGE POINT Q (I,J+1/2)
        REAL, DIMENSION(:, :, :), POINTER :: DH            ! BEING USED FOR SEDIMENT TRANSPORT
        REAL, DIMENSION(:, :, :), POINTER :: DZ            ! TOTAL WATER DEPTH, FOR MOVING BOUNDARY
        REAL, DIMENSION(:, :), POINTER :: R1            ! R0 TO R6 : COEFFICIENTS FOR SPHERICAL COORD
        REAL, DIMENSION(:, :), POINTER :: R2
        REAL, DIMENSION(:, :), POINTER :: R3
        REAL, DIMENSION(:, :), POINTER :: R4
        REAL, DIMENSION(:, :), POINTER :: R5
        REAL, DIMENSION(:), POINTER :: R6
        REAL, DIMENSION(:, :), POINTER :: R0            ! R0 : COEFFICIENTS FOR SPHERICAL COORD
        REAL, DIMENSION(:, :), POINTER :: R11            ! R21: COEFFICIENTS FOR SPHERICAL COORD
        REAL, DIMENSION(:, :), POINTER :: R21            ! R21: COEFFICIENTS FOR SPHERICAL COORD
        REAL, DIMENSION(:, :), POINTER :: R22            ! R21: COEFFICIENTS FOR SPHERICAL COORD
        REAL, DIMENSION(:, :), POINTER :: XFLUX        ! INTERNAL USE, VOLUME FLUX AT CONNECTING INTERFACE, FOR FLUX INTERPOLATION THROUGH NESTING INTERFACE
        REAL, DIMENSION(:, :), POINTER :: YFLUX        ! INTERNAL USE, VOLUME FLUX AT CONNECTING INTERFACE, FOR FLUX INTERPOLATION THROUGH NESTING INTERFACE
        !	REAL, ALLOCATABLE	:: XFLUX(:,:)
        !	REAL, ALLOCATABLE	:: YFLUX(:,:)
        REAL, DIMENSION(:), POINTER :: X            ! X COORDINATE OF GRIDS
        REAL, DIMENSION(:), POINTER :: Y            ! Y COORDINATE OF GRIDS
        REAL, DIMENSION(:), POINTER :: XT            ! X COORDINATE OF GRIDS (TEMP)
        REAL, DIMENSION(:), POINTER :: YT            ! Y COORDINATE OF GRIDS (TEMP)
        REAL :: DX                        ! GRID SIZE IN X DIRECTION
        REAL :: DY                        ! GRID SIZE IN Y DIRECTION
        REAL, DIMENSION(:), POINTER :: DEL_X        ! VARIABLE GRID SIZE IN X DIRECTION
        REAL, DIMENSION(:), POINTER :: DEL_Y        ! VARIABLE GRID SIZE IN Y DIRECTION
        REAL :: DT                        ! TIME STEP
        REAL :: RX                        ! R=DT/DX
        REAL :: RY                        ! R=DT/DY
        REAL :: GRX                        ! GR=GRAV*DT/DX
        REAL :: GRY                        ! GR=GRAV*DT/DY
        INTEGER :: INI_SWITCH                ! SWITCH FOR INITIAL CONDITION
        INTEGER :: BC_TYPE                    ! BOUNDARY CONDITION (FOR LAYER01 ONLY)
        INTEGER :: DIM                        ! DIMENSION: 1 -- ONE-DIMENSIONAL; 2 -- TWO-DIMENSIONAL
        INTEGER :: LINCHK                    ! FOR INTERNAL PURPOSE, 0 - WITHOUT CONVECTION TERMS; 1- WITH CONVECTION TERMS
        INTEGER :: MODSCM                    ! FOR INTERNAL PURPOSE, 0 - WITH MODIFIED SCHEME; 1 - WITHOUT MODIFIED SCHEME
        !VARIABLES RELATED TO BOTTOM FRICTION
        INTEGER :: FRIC_SWITCH                ! 0-USE MANNING'S FORMULA,CONST. COEF;1-NO FRICTION; 2-VARIABLE COEF; 3-SEDIMENT TRANS
        REAL :: FRIC_COEF                ! MANNING'S ROUGHNESS COEFFICIENT
        REAL, DIMENSION(:, :), POINTER :: FRIC_VCOEF   ! VARIABLE MANNING'S ROUGHNESS COEF.
        !VARIABLES RELATED TO NUMERICAL DISPERSION
        INTEGER, DIMENSION(:, :), POINTER :: MASK
        REAL, DIMENSION(:, :), POINTER :: ALPHA        ! VARIABLE FOR IMPROVEMENT OF NUMERICAL DISPERSION
        REAL, DIMENSION(:, :), POINTER :: A1X
        REAL, DIMENSION(:, :), POINTER :: A2X
        REAL, DIMENSION(:, :), POINTER :: A1Y
        REAL, DIMENSION(:, :), POINTER :: A2Y
        REAL, DIMENSION(:, :, :), POINTER :: CF
        REAL, DIMENSION(:, :, :), POINTER :: CB
        REAL, DIMENSION(:, :), POINTER :: M0            ! VOLUME FLUX IN X AT T=N-1
        REAL, DIMENSION(:, :), POINTER :: N0            ! VOLUME FLUX IN Y AT T=N-1
        REAL, DIMENSION(:, :), POINTER :: SPONGE_COEFX    !COEFICIENTS USED FOR SPONGE LAYER IMPLEMENTATION
        REAL, DIMENSION(:, :), POINTER :: SPONGE_COEFY    !COEFICIENTS USED FOR SPONGE LAYER IMPLEMENTATION
        REAL, DIMENSION(:, :), POINTER :: Z_MAX        ! MAXIMUM WATER SURFACE ELEVATION
        REAL, DIMENSION(:, :), POINTER :: Z_MIN        ! MAXIMUM WATER SURFACE DEPRESSION
        REAL :: SOUTH_LAT !F				! LATTITUDE OF SOUTH BOUNDARY (NOTE: SOUTH EDGE OF BOTTOM GRID CELLS !!!)
        INTEGER :: LAYCORD                    ! COORDINATE, 0-SPHERI, 1-CART
        INTEGER :: LAYGOV                    ! GOVERNING EQ. 0-LINEAR, 1-NONLINEAR
        INTEGER :: LAYSWITCH                ! SWITCH TO TURN ON/OFF CURRENT GRID
        INTEGER :: FLUXSWITCH                ! FLUX OUTPUT SWITCH: 0-OUTPUT FLUX, 1-NO FLUX OUTPUT
        INTEGER :: SEDI_SWITCH                ! SEDIMENT TRANSPORT: 0-ENABLE, 1-DISABLE
        INTEGER :: REL_SIZE                    ! GRID SIZE RATIO OF PARENT GRID TO CHILD GRID
        INTEGER :: REL_TIME                    ! TIME STEP RATIO OF PARENT GRID TO CHILD GRID
        INTEGER :: NUM_CHILD                ! # OF CHILDREN GRIDS
        INTEGER, DIMENSION(4) :: CORNERS        ! INDICE OF CURRENT GRID'S FOUR CORNER IN ITS PARENT GRID
        ! CORNESR(1)=XS;CORNERS(2)=XE;CORNERS(3)=YS;CORNERS(4)=YE
        REAL :: X_START        ! X COORDINATE OF THE LOWER-LEFT CORNER GRID
        REAL :: Y_START        ! Y COORDINATE OF THE LOWER-LEFT CORNER GRID
        REAL :: X_END            ! X COORDINATE OF THE UPPER-RIGHT CORNER GRID
        REAL :: Y_END            ! Y COORDINATE OF THE UPPER-RIGHT CORNER GRID

        REAL :: XO                ! X COORDINATE OF THE LOWER-LEFT CORNER GRID IN DEGREES
        REAL :: YO                ! Y COORDINATE OF THE LOWER-LEFT CORNER GRID IN DEGREES

        REAL                   H_LIMIT                    ! WATER DEPTH LIMIT, LOWER THAN THIS VALUE WILL BE TREATED AS LAND
        REAL                   TIDE_LEVEL                ! TIDAL CORRECTION TO THE MEAN SEA LEVEL (HIGH TIDE > 0; LOW TIDE < 0)
        LOGICAL                UPZ                        ! ONLY .TRUE. WHEN CARTESIAN GRID IS NESTED IN SPHERICAL GRIDS
        INTEGER :: SC_OPTION                ! OPTION SWITCH TO SELECT COUPLING METHOD BETWEEN SPHERICAL AND CARTESIAN
        INTEGER, DIMENSION(:, :, :), POINTER :: POS        ! USED WHEN CARTESIAN GRID IS NESTED IN SPHERICAL GRIDS
        REAL, DIMENSION(:, :, :), POINTER :: CXY        ! USED WHEN CARTESIAN GRID IS NESTED IN SPHERICAL GRIDS

    END TYPE LAYER
END MODULE LAYER_PARAMS

!//////////////////////////////////////////////////////////////////////
! PARAMETER DEFINITION MODULE FOR WAVE MAKER
!//////////////////////////////////////////////////////////////////////
MODULE WAVE_PARAMS
    TYPE WAVE
        INTEGER :: MK_TYPE                            ! WAVE TYPE  (0:SINE, 1: SOLITARY, 2:GIVEN FORM, 3:FOCUSING SOLITARYWAVE)
        INTEGER :: INCIDENT                            ! INCIDENT DIRECTION(1:TOP,2:B,3:LF,4:RT,5:OBLIQUE)
        INTEGER :: MK_BC                            ! B.C. AFTER SENDING WAVE IN (1:SOLID, 0:OPEN)
        REAL :: WK_END                            ! TIME TO CHANGE BOUNDARY SENDING WAVE IN, (SEC)
        REAL :: W                                ! WAVE ANGULAR FREQUENCY
        REAL :: AMP                                ! CHARACTERISTIC WAVE HEIGHT (METER)
        REAL :: DEPTH                            ! CHARACTERISTIC WATER DEPTH (METER)
        REAL :: POINT(2)                            ! FOCUS FOR FOCUSING WAVE (POINT(1)=X0, POINT(2)=Y0)
        REAL :: ANG                                ! ANGLE FOR OBLIQUE WAVE (IN DEGREES)
        CHARACTER(120) :: FORM_NAME                        ! FILENAME OF TIMEHISTORY INPUT FILE, FOR FUTURE USE
        INTEGER :: FORM_LEN                            ! NUMBER OF ENTRIES (LINES) IN A GIVEN TIMEHISTORY INPUT FILE
        REAL, DIMENSION(:), POINTER :: T                ! TIME FOR A GIVEN TIME HISTORY INPUT
        REAL, DIMENSION(:), POINTER :: FSE                ! FREE SURFACE ELEVATION FOR A GIVEN TIME HISTORY INPUT
    END TYPE WAVE
END MODULE WAVE_PARAMS

!//////////////////////////////////////////////////////////////////////
! PARAMETER MODULE FOR FAULT MODEL
!//////////////////////////////////////////////////////////////////////
MODULE FAULT_PARAMS
    TYPE FAULT
        REAL :: HH                    ! FOCAL DEPTH, MEASURED FROM MEAN EARTH SURFACE TO THE TOP EDGE OF FAULT PLANE
        REAL :: L                    ! LENGTH OF THE FAULT PLANE
        REAL :: W                    ! WIDTH OF THE FAULT PLANE
        REAL :: D                    ! DISLOCATION
        REAL :: TH                    ! (=THETA) STRIKE DIRECTION
        REAL :: DL                    ! (=DELTA) DIP ANGLE
        REAL :: RD                    ! (=LAMDA) SLIP ANGLE
        REAL :: YO                    ! ORIGIN OF COMPUTATIONAL DOMAIN (LATITUDE IN DEGREES)
        REAL :: XO                    ! ORIGIN OF COMPUTATIONAL DOMAIN (LONGITUDE IN DEGREES)
        REAL :: Y0                    ! EPICENTER (LATITUDE)
        REAL :: X0                    ! EPICENTER (LONGITUDE)
        REAL :: T0                    ! TIME WHEN THE RUTPURE STARTS
        INTEGER :: SWITCH                ! DEFORMATION CALCULATION SWITCH: 0 - FAULT MODEL; 1 - DATAFILE
        INTEGER :: NUM_FLT                ! TOTAL NUMBER OF FAULT PLANES
        INTEGER :: FS                    ! OPTION: CONTROLLING INPUT DATA FORMAT
        CHARACTER(120) :: DEFORM_NAME  ! FILENAME OF DEFORMATION DATA
    END TYPE FAULT
END MODULE FAULT_PARAMS

!//////////////////////////////////////////////////////////////////////
! PARAMETER MODULE FOR SUBMARINE LAND SLIDE MODEL
!//////////////////////////////////////////////////////////////////////
MODULE LANDSLIDE_PARAMS
    TYPE LANDSLIDE
        INTEGER :: NX                    ! TOTAL X GRIDS OF LANDSLIDE REGION IN LAYER 1
        INTEGER :: NY                    ! TOTAL Y GRIDS OF LANDSLIDE REGION IN LAYER 1
        INTEGER, DIMENSION(4) :: CORNERS                ! INDICES OF LANDSLIDE REGION IN LAYER 1
        REAL :: X_START
        REAL :: Y_START
        REAL :: X_END
        REAL :: Y_END
        REAL :: XS                    ! X COORD.OF STARTING LOCATION OF LANDSLIDE
        REAL :: YS                    ! Y COORD.OF STARTING LOCATION OF LANDSLIDE
        REAL :: XE                    ! X COORD.OF ENDING LOCATION OF LANDSLIDE
        REAL :: YE                    ! Y COORD.OF ENDING LOCATION OF LANDSLIDE
        REAL :: DISTANCE                ! DISTANCE OF LANDSLIDE MOTION
        REAL :: SLOPE                    ! EFFECTIVE SLOPE OF LANDSLIDE PATH
        REAL :: A                        ! SEMI-MAJOR AXIS
        REAL :: B                        ! SEMI-MINOR AXIS
        REAL :: THICKNESS                ! THICKNESS OF SLIDING VOLUME
        REAL, DIMENSION(:, :, :), POINTER :: SNAPSHOT        ! SNAPSHOTS OF TRANSIENT WATER DEPTH DUE TO LANDSLIDE
        INTEGER :: NT                    ! TOTAL # OF SNAPSHOTS OF LANDSLIDE DATA
        REAL :: DURATION                ! TOTAL DURATION OF LANDSLIDE
        REAL, DIMENSION(:), POINTER :: T                ! TIME SEQUENCE CORRESPONDS TO WATERDEPTH SNAPSHOTS
        INTEGER :: OPTION                ! OPTION: CONTROLLING INPUT DATA
        CHARACTER(120) :: FILENAME                ! FILENAME OF INPUT DATA
    END TYPE LANDSLIDE
END MODULE LANDSLIDE_PARAMS
!//////////////////////////////////////////////////////////////////////
! PARAMETER MODULE FOR INPUT BOUNDARY CONDITION (FACTS)
!//////////////////////////////////////////////////////////////////////
MODULE BCI_PARAMS
    TYPE BCI
        INTEGER :: NX                !
        INTEGER :: NY                !
        INTEGER :: NT                !
        REAL :: DURATION            !
        REAL, DIMENSION(:), POINTER :: X
        REAL, DIMENSION(:), POINTER :: Y
        REAL, DIMENSION(:), POINTER :: T                !
        REAL, DIMENSION(:, :, :), POINTER :: Z_VERT        !
        REAL, DIMENSION(:, :, :), POINTER :: Z_HORI        !
        REAL, DIMENSION(:, :, :), POINTER :: U_VERT        !
        REAL, DIMENSION(:, :, :), POINTER :: U_HORI        !
        REAL, DIMENSION(:, :, :), POINTER :: V_VERT        !
        REAL, DIMENSION(:, :, :), POINTER :: V_HORI        !
        REAL, DIMENSION(:, :, :), POINTER :: SNAPSHOT
        REAL, DIMENSION(:, :, :), POINTER :: SNAPSHOTU
        REAL, DIMENSION(:, :, :), POINTER :: SNAPSHOTV
        INTEGER :: FS                    !
        CHARACTER(120) :: FNAMEH                !
        CHARACTER(120) :: FNAMEU                !
        CHARACTER(120) :: FNAMEV                !
    END TYPE BCI
END MODULE BCI_PARAMS
