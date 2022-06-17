!----------------------------------------------------------------------
SUBROUTINE READ_CONFIG (LO, LA, TEND, TMIN_INV, INI_SURF, &
        WAVE_INFO, FAULT_INFO, LANDSLIDE_INFO, &
        BCI_INFO, START_TYPE, START_TIME, BC_TYPE, &
        OUT_OPT, JOB)
    !......................................................................
    !DESCRIPTION:
    !	  #. OBTAIN ALL THE PARAMETERS FROM COMCOT.CTL;
    !	  #. START_TYPE =
    !				0: COLD START (SIMULATION STARTS FROM T = 0)
    !				1: HOT START (SIMULATION STARTS FROM RESUMING TIME)
    !				20: COLD START WITH TIDE LEVEL ADJUSTMENT
    !				21: HOT START WITH TIDE LEVEL ADJUSTMENT
    !	  #. INI_SURF =
    !				0: USE FAULT MODEL TO DETERMINE SEAFLOOR DEFORMATION
    !				1: USE DATA FILE TO DETERMINE INITIAL WATER SURFACE
    !				2: USE INCIDENT WAVE MODEL TO GENERATE WAVES
    !				3: USE TRANSIENT FLOOR MOTION MODEL (LANDSLIDE);
    !				4: USE FAULT MODEL + LANDSLIDE;
    !				   FAULT_MULTI.CTL IS REQUIRED FOR MULTI-FAULT SETUP;
    !				9: USE MANSINHA AND SMYLIES' MODEL TO CALC DEFORMATION
    !INPUT:
    !	  #. COMCOT.CTL (AND FAULT_MULTI.CTL FOR MORE THAN ONE FAULT PLANE)
    !OUTPUT:
    !	  #. GENERAL INFORMAITON FOR A SIMULATION;
    !     #. GRID SETUP;
    !NOTES:
    !     #. CREATED INITIALLY BY TOM LOGAN, ARSC (2005)
    !     #. MODIFIED BY XIAOMING WANG (SEP 2005)
    !     #. UPDATED ON SEP17 2006 (XIAOMING WANG, CORNELL UNIV.)
    !     #. UPDATED ON NOV 21 2008 (XIAOMING WANG, GNS)
    !     #. UPDATED ON DEC 22 2008 (XIAOMING WANG, GNS)
    !	  #. UPDATED ON JAN05 2009 (XIAOMING WANG, GNS)
    !	  #. UPDATED ON APR03 2009 (XIAOMING WANG)
    !		 1. IMPROVE COUPLING SCHEME BETWEEN SPHERICAL AND CARTESIAN
    !	  #. UPDATED ON APR09 2009 (XIAOMING WANG, GNS)
    !		 1. ADD SUPPORT ON IMPORTING MULTIPLE FAULT PLANE PARAMETERS
    !			FROM A DATA FILE;
    !-------------------------------------------------------------------------
    USE LAYER_PARAMS
    USE WAVE_PARAMS
    USE FAULT_PARAMS
    USE LANDSLIDE_PARAMS
    USE BCI_PARAMS
    TYPE (LAYER) :: LO
    TYPE (LAYER), DIMENSION(NUM_GRID) :: LA
    TYPE (WAVE) :: WAVE_INFO
    TYPE (FAULT), DIMENSION(NUM_FLT) :: FAULT_INFO
    TYPE (LANDSLIDE) :: LANDSLIDE_INFO
    TYPE (BCI) :: BCI_INFO
    INTEGER :: INI_SURF
    REAL :: TEND, TMIN_INV, FM, DT, H_LIMIT, START_TIME
    REAL :: ARC
    INTEGER :: I, J, K, LAYNUM, STAT, POS, PARENT
    INTEGER :: COUNT
    INTEGER :: BC_TYPE
    INTEGER :: OUT_OPT
    INTEGER :: START_TYPE, START_STEP
    CHARACTER(LEN = 200) :: LINE, LINE1, LINE2, LINE3
    CHARACTER(LEN = 200) :: DUMP, TMP, TMPNAME, FNAME
    CHARACTER(LEN = 200) :: JOB
    COMMON /CONS/ ELMAX, GRAV, PI, R_EARTH, GX, EPS, ZERO, ONE, NUM_GRID, &
            NUM_FLT, V_LIMIT, RAD_DEG, RAD_MIN

    !LOAD CONTROL FILE COMCOT.CTL
    WRITE(*, *) 'READING PARAMETERS FOR SIMULATION...'
    OPEN(UNIT = 666, FILE = 'comcot.ctl', STATUS = 'OLD', IOSTAT = ISTAT)
    IF (ISTAT /=0) THEN
        PRINT *, "ERROR:: CAN'T OPEN CONFIG FILE COMCOT.CTL; EXITING."
        STOP
    END IF

    !----------------------------------------------
    ! READING GENERAL PARAMETERS FOR SIMULATION
    !----------------------------------------------
    WRITE (*, *) '    READING GENERAL INFORMATION......'
    READ (666, '(8/)')
    READ (666, '(A)')          DUMP                    !  READ JOB DESCRIPTION
    READ (666, '(49X,F30.6)')  TEND                    !  TOTAL SIMULATED PHYSICAL TIME
    READ (666, '(49X,F30.6)')  TMIN_INV                !  TIME INTERVAL FOR DATA OUTPUT
    READ (666, '(49X,I30)')    OUT_OPT                    !  0-OUTPUT MAX TSUNAI AMP; 1-OUTPUT TIMEHISTORY; 2-OUTPUT BOTH
    READ (666, '(49X,I30)')    START_TYPE                !  0-COLD START (T=0.0); 1-HOT START (FROM T = START_TIME); 20-COLDSTART WITH TIDE CORRECTION; 21-HOTSTART WITH TIDE CORRECTION
    READ (666, '(49X,F30.6)')  START_TIME                !  STARTING TIME STEP IF HOT START
    READ (666, '(49X,F30.6)')  H_LIMIT                    !  LIMITATION ON WATER DEPTH, SHALLOWER THAN THIS WILL BE TREATED AS LAND; 0.0 MEANS ORIGINAL SHORELINE WITHOUT VERTICAL WALL
    READ (666, '(49X,I30)')    INI_SURF                !  INITIAL CONDITION: 0-FAULT; 1-FILE; 2-WAVEMAKER;3-LANDSLIDE;4-FAULT+LANDSLIDE
    READ (666, '(49X,I30)')    BC_TYPE                    !  BOUNDARY CONDITION: 0- RADIATION;1-SPONGE;2-WALL;3-FACTS
    READ (666, '(A)')          LINE1                    !  READ FILE NAME OF Z INPUT
    READ (666, '(A)')          LINE2                    !  READ FILE NAME OF U INPUT
    READ (666, '(A)')          LINE3                    !  READ FILE NAME OF V INPUT

    JOB = DUMP

    POS = INDEX(LINE1, ':')
    IF (POS>0) THEN
        BCI_INFO%FNAMEH = TRIM(LINE1(POS + 1:200))
    ELSE
        BCI_INFO%FNAMEH = ' '
    ENDIF
    LINE1 = ''
    POS = INDEX(LINE2, ':')
    IF (POS>0) THEN
        BCI_INFO%FNAMEU = TRIM(LINE2(POS + 1:200))
    ELSE
        BCI_INFO%FNAMEU = ' '
    ENDIF
    LINE2 = ''
    POS = INDEX(LINE3, ':')
    IF (POS>0) THEN
        BCI_INFO%FNAMEV = TRIM(LINE3(POS + 1:200))
    ELSE
        BCI_INFO%FNAMEV = ' '
    ENDIF
    LINE3 = ''

    IF (BC_TYPE.EQ.3) INI_SURF = 999

    !----------------------------------------
    !  READING PARAMETERS FOR FAULT MODEL
    !----------------------------------------
    IF (INI_SURF.EQ.0 .OR. INI_SURF.EQ.4) THEN
        WRITE (*, *) '    READING PARAMETERS FOR FAULT MODEL......'
    ENDIF
    READ (666, '(3/)')
    READ (666, '(49X,I30)')   FAULT_INFO(1)%NUM_FLT    ! TOTAL NO. OF FAULT PLANES
    IF (INI_SURF.EQ.0 .OR. INI_SURF.EQ.4) THEN
        IF (FAULT_INFO(1)%NUM_FLT.GT.1) THEN
            WRITE (*, *) '    MULTI-FAULTING CONFIGURATION IS IMPLEMENTED'
            IF (FAULT_INFO(1)%NUM_FLT.NE.999) THEN
                K = 1
                WRITE (*, *) '    READING PARAMETERS FOR FAULT SEGMENT', K
            ENDIF
        ENDIF
    ENDIF
    READ (666, '(49X,F30.6)') FAULT_INFO(1)%T0         !  RUPTURING TIME OF FAULT PLANE 01
    READ (666, '(49X,I30)')   FAULT_INFO(1)%SWITCH     !  OPTION: 1 - MODEL; 2 - DATA;
    READ (666, '(49X,F30.6)') FAULT_INFO(1)%HH            !  FOCAL DEPTH (UNIT: METER)
    READ (666, '(49X,F30.6)') FAULT_INFO(1)%L            !  LENGTH OF SOURCE AREA (UNIT: METER)
    READ (666, '(49X,F30.6)') FAULT_INFO(1)%W            !  WIDTH OF SOURCE AREA (UNIT: METER)
    READ (666, '(49X,F30.6)') FAULT_INFO(1)%D            !  DISLOCATION (UNIT: METER)
    READ (666, '(49X,F30.6)') FAULT_INFO(1)%TH            !  (=THETA) STRIKE DIRECTION (UNIT: DEGREE)
    READ (666, '(49X,F30.6)') FAULT_INFO(1)%DL            !  (=DELTA) DIP ANGLE (UNIT : DEGREE)
    READ (666, '(49X,F30.6)') FAULT_INFO(1)%RD            !  (=LAMDA) SLIP ANGLE (UNIT: DEGREE)
    READ (666, '(49X,F30.6)') FAULT_INFO(1)%YO            !  ORIGIN OF COMPUTATION (LATITUDE :DEGREE)
    READ (666, '(49X,F30.6)') FAULT_INFO(1)%XO            !  ORIGIN OF COMPUTATION (LONGITUDE:DEGREE)
    READ (666, '(49X,F30.6)') FAULT_INFO(1)%Y0            !  EPICENTER (LATITUDE :DEGREE)
    READ (666, '(49X,F30.6)') FAULT_INFO(1)%X0            !  EPICENTER (LONGITUDE:DEGREE)
    READ (666, '(A)')         LINE                        !  NAME OF DEFORMATION DATA FILE
    READ (666, '(49X,I30)')   FAULT_INFO(1)%FS            !  FORMAT OF DEFORMATION FILE:0-COMCOT;1-MOST;2-XYZ

    POS = INDEX(LINE, ':')
    IF (POS>0) THEN
        FAULT_INFO(1)%DEFORM_NAME = TRIM(LINE(POS + 1:200))
    ELSE
        FAULT_INFO(1)%DEFORM_NAME = 'ini_surface.dat'
    ENDIF
    LINE = ''
    SN = SIN(RAD_DEG * FAULT_INFO(1)%DL)
    CS = COS(RAD_DEG * FAULT_INFO(1)%DL)
    IF (ABS(SN) .LT. EPS) FAULT_INFO(1)%DL = FAULT_INFO(1)%DL + EPS
    IF (ABS(CS) .LT. EPS) FAULT_INFO(1)%DL = FAULT_INFO(1)%DL + EPS
    ! READING PARAMETERS FOR OTHER FAULT PLANES IF > 1
    IF (INI_SURF.EQ.0 .OR. INI_SURF.EQ.4) THEN
        IF (FAULT_INFO(1)%NUM_FLT.GT.1) THEN
            IF (FAULT_INFO(1)%NUM_FLT.NE.999) THEN
                CALL GET_MULTIFAULT_PARAMETERS (LO, FAULT_INFO)
            ELSE
                CALL READ_MULTIFAULT_DATA (LO, FAULT_INFO)
            ENDIF
        ENDIF
    ENDIF

    !----------------------------------------
    !  READING PARAMETERS FOR WAVE MAKER
    !----------------------------------------
    IF (INI_SURF .EQ. 2) THEN
        WRITE (*, *) '    READING PARAMETERS FOR WAVE MAKER......'
    ENDIF
    READ (666, '(3/)')
    READ (666, '(49X,I30)')   WAVE_INFO%MK_TYPE        !  WAVE TYPE ( 1:SOLITARY WAVE; 2:GIVEN FORM)
    READ (666, '(A)')         LINE                        !  FILENAME OF CUSTOMIZED INPUT PROFILE, ONLY FOR WAVE TYPE=2
    READ (666, '(49X,I30)')   WAVE_INFO%INCIDENT        !  WAVE INCIDENT DIRECTION: (1:TOP,2:BOTTOM,3:LEFT,4RIGHT)
    READ (666, '(49X,F30.6)') WAVE_INFO%AMP            !  CHARACTERISTIC WAVE HEIGHT (UNIT: METER)
    READ (666, '(49X,F30.6)') WAVE_INFO%DEPTH            !  CHARACTERISTIC WATER DEPTH (IN METERS)

    ! OBTAIN FILENAME OF GIVEN PROFILE
    POS = INDEX(LINE, ':')
    IF (POS>0) THEN
        WAVE_INFO%FORM_NAME = TRIM(LINE(POS + 1:200))
    ELSE
        WAVE_INFO%FORM_NAME = 'fse.dat'
    ENDIF
    LINE = ''
    WAVE_INFO%WK_END = TEND
    WAVE_INFO%MK_BC = 0

    !-----------------------------------------
    !READING PARAMETERS FOR LAND SLIDE MODEL
    !----------------------------------------
    IF (INI_SURF .EQ. 3) THEN
        WRITE (*, *) '    READING PARAMETERS FOR LAND SLIDE MODEL......'
    ENDIF
    READ (666, '(3/)')
    READ (666, '(49X,F30.6)')   LANDSLIDE_INFO%X_START  !  STARTING X COORD. OF LAND SLIDE REGION
    READ (666, '(49X,F30.6)')   LANDSLIDE_INFO%X_END    !  ENDING X COORD. OF LAND SLIDE REGION
    READ (666, '(49X,F30.6)')   LANDSLIDE_INFO%Y_START  !  STARTING Y COORD. OF LAND SLIDE REGION
    READ (666, '(49X,F30.6)')   LANDSLIDE_INFO%Y_END    !  ENDING Y COORD. OF LAND SLIDE REGION
    READ (666, '(A)')           LINE                    !  NAME OF LANDSLIDE SNAPSHOT DATA FILE
    READ (666, '(49X,I30)')     LANDSLIDE_INFO%OPTION   !  FORMAT OF LANDSLIDE:0-OLD COMCOT;1-XYT;2-FUNCTION

    POS = INDEX(LINE, ':')
    IF (POS>0) THEN
        LANDSLIDE_INFO%FILENAME = TRIM(LINE(POS + 1:200))
    ENDIF
    !	  WRITE(*,*) LO%DEPTH_NAME
    LINE = ''

    !-----------------------------------------
    !  READING PARAMETERS FOR LAYER 1
    !-----------------------------------------
    WRITE (*, *) '    READING PARAMETERS FOR GRID LAYER......'
    READ (666, '(5/)')
    READ (666, '(49X,I30)')    LO%LAYSWITCH            !  SWITCH TO THIS LAYER:0-RUN THIS LAYER;1-DON'T RUN THIS LAYER
    READ (666, '(49X,I30)')    LO%LAYCORD                !  COORDINATES: 0-SPHERICAL; 1-CARTESIAN
    READ (666, '(49X,I30)')    LO%LAYGOV                !  GOVERNING EQUATION: 0-LINEAR SWE; 1-NONLINEAR SWE; 2-LSWE W/ DISP.; 3-NLSWE W/ DISP.
    READ (666, '(49X,F30.6)')  LO%DX                    !  GRID SIZE; IN MUNITES FOR SPHERICAL COORD., IN METERS FOR CARTESIAN
    READ (666, '(49X,F30.6)')  LO%DT                    !  TIME STEP SIZE, IN SECONDS; WILL BE ADJUSTED IF CFL STABILITY CONDITION NOT SATISFIED;
    READ (666, '(49X,I30)')    LO%FRIC_SWITCH            !  FRICTION SWITCH: 0-CONSTANT ROUGHNESS;1-NO ROUGHNESS;2-VARIABLE ROUGHNESS, ROUGHNESS DATA FILE REQUIRED;
    READ (666, '(49X,F30.6)')  LO%FRIC_COEF            !  MANNING'S ROUGHNESS COEF FOR FRICTION SWITCH = 0;
    READ (666, '(49X,I30)')    LO%FLUXSWITCH            !  OUTPUT OPTION: 0-Z+HU+HZ; 1-Z; 2-NONE; 9-Z W/ MODIFIED BATHYMETRY;
    READ (666, '(49X,F30.6)')  LO%X_START                !  STARTING X COORDINATE OF COMPUTATIONAL DOMAIN
    READ (666, '(49X,F30.6)')  LO%X_END                !  ENDING X COORDINATE OF COMPUTATIONAL DOMAIN
    READ (666, '(49X,F30.6)')  LO%Y_START                !  STARTING Y COORDINATE OF COMPUTATIONAL DOMAIN
    READ (666, '(49X,F30.6)')  LO%Y_END                !  ENDING Y COORDINATE OF COMPUTATIONAL DOMAIN
    READ (666, '(A)')          LINE                    !  NAME OF BATHYMETRY DATA FILE FOR LAYER01
    READ (666, '(49X,I30)')    LO%FS                    !  FORMAT OF BATHYMETRY DATA: 0-OLD COMCOT; 1-MOST-FORMATTED; 2-XYZ; 3-ETOPO
    READ (666, '(49X,I30)')    LO%ID                    !  GRID IDENTIIFCATION NUMBER
    READ (666, '(49X,I30)')    LO%LEVEL                !  GRID LEVEL IN NESTED GRID HIERACHY
    READ (666, '(49X,I30)')    LO%PARENT                !  ID OF IT'S PARENT GRID

    POS = INDEX(LINE, ':')
    IF (POS>0) THEN
        LO%DEPTH_NAME = TRIM(LINE(POS + 1:200))
        !*	     TMP = TRIM(LINE(POS+1:200))
        !*	     POS = INDEX(TRIM(TMP),' ',BACK=.TRUE.)
        !*		 LEN_CHAR = LEN_TRIM(TMP(POS+1:200))
        !*	     LO%DEPTH_NAME = TRIM(TMP(POS+1:POS+LEN_CHAR))
    ELSE
        LO%DEPTH_NAME = 'layer01.dep'
    ENDIF
    !*	  WRITE(*,*) LEN_CHAR,LO%DEPTH_NAME
    LINE = ''
    LO%LAYSWITCH = 0
    LO%ID = 1

    !     TIDAL LEVEL CORRECTION CONTRAL
    LO%TIDE_LEVEL = 0.0        ! RUN AT MEAN SEA LEVEL
    IF (START_TYPE.EQ.20 .OR. START_TYPE.EQ.21) THEN
        IF (START_TYPE.EQ.20) START_TYPE = 0
        IF (START_TYPE.EQ.21) START_TYPE = 1
        WRITE (*, *) '>>>>PLEASE INPUT TIDAL LEVEL CORRECTION TO MSL:'
        READ *, LO%TIDE_LEVEL
    ENDIF

    !	  GENERATE 'SQUARE' GRIDS FOR DISPERSION-IMPROVED SCHEME
    IF (LO%LAYGOV.GE.2) LO%PARENT = 0
    LO%DIM = 2
    IF (BC_TYPE.EQ.9) LO%DIM = 1
    !*	  LO%PARENT = -1
    LO%H_LIMIT = H_LIMIT
    LO%INI_SWITCH = INI_SURF
    LO%BC_TYPE = BC_TYPE
    LO%UPZ = .TRUE.
    LO%SC_OPTION = 0

    IF (LO%LAYCORD .EQ. 0) THEN
        LO%SOUTH_LAT = LO%Y_START
    ELSE
        LO%SOUTH_LAT = FAULT_INFO(1)%YO
        LO%XO = FAULT_INFO(1)%XO
        LO%YO = FAULT_INFO(1)%YO
    ENDIF

    CALL DX_CALC (LO)

    START_STEP = NINT(START_TIME / LO%DT)

    IF (LO%LAYCORD.EQ.0) THEN
        FAULT_INFO(1)%YO = LO%Y_START
        FAULT_INFO(1)%XO = LO%X_START
    ENDIF
    WRITE (*, *) '    READING PARAMETERS FOR GRID LAYER ID', LO%ID

    !----------------------------------------
    !  READING PARAMETERS FOR SUB-LEVEL GRIDS
    !----------------------------------------
    !.....READING PARAMETERS FOR SUB GRIDS
    !.....READING PARAMETERS FOR SUB-LEVEL GRIDS: LAYER02 TO LAYER13
    DO I = 1, NUM_GRID
        READ (666, '(3/)')
        READ (666, '(49X,I30)')    LA(I)%LAYSWITCH
        READ (666, '(49X,I30)')    LA(I)%LAYCORD
        READ (666, '(49X,I30)')    LA(I)%LAYGOV
        READ (666, '(49X,I30)')    LA(I)%FRIC_SWITCH
        READ (666, '(49X,F30.6)')  LA(I)%FRIC_COEF
        READ (666, '(49X,I30)')    LA(I)%FLUXSWITCH
        READ (666, '(49X,I30)')    LA(I)%REL_SIZE        !  GRID SIZE RATIO OF IT'S PARENT GRID TO THIS GRID
        READ (666, '(49X,F30.6)')  LA(I)%X_START        !  STARTING X COORDINATE OF THIS GRID LAYER IN ITS PARENT GRID
        READ (666, '(49X,F30.6)')  LA(I)%X_END            !  ENDING X COORDINATE OF THIS GRID LAYER IN ITS PARENT GRID
        READ (666, '(49X,F30.6)')  LA(I)%Y_START        !  STARTING Y COORDINATE OF THIS GRID LAYER IN ITS PARENT GRID
        READ (666, '(49X,F30.6)')  LA(I)%Y_END            !  ENDING Y COORDINATE OF THIS GRID LAYER IN ITS PARENT GRID
        READ (666, '(A)')          LINE                    !  NAME OF BATHYMETRY DATA FILE FOR LAYER21
        READ (666, '(49X,I30)')    LA(I)%FS                !  FORMAT OF BATHYMETRY DATA
        READ (666, '(49X,I30)')    LA(I)%ID                !  GRID IDENTIFICATION NUMBER
        READ (666, '(49X,I30)')    LA(I)%LEVEL            !  GRID LEVEL IN NESTED GRID CONFIGURATION
        READ (666, '(49X,I30)')    LA(I)%PARENT            !  ID OF ITS PARENT GRID LAYER

        POS = INDEX(LINE, ':')
        IF (POS>0) THEN
            LA(I)%DEPTH_NAME = TRIM(LINE(POS + 1:200))
        ELSE
            WRITE (FNAME, 1) LA(I)%ID
            1          FORMAT('layer', I2.2, '.dep')
            LA(I)%DEPTH_NAME = FNAME
            FNAME = ''
        ENDIF
        !	     WRITE(*,*) LA(I)%DEPTH_NAME
        LINE = ''
        LA(I)%H_LIMIT = H_LIMIT
        LA(I)%TIDE_LEVEL = LO%TIDE_LEVEL
        LA(I)%INI_SWITCH = INI_SURF
        LA(I)%BC_TYPE = BC_TYPE
        LA(I)%DIM = 2
        IF (BC_TYPE .EQ. 9) LA(I)%DIM = 1
        LA(I)%UPZ = .TRUE.  ! UPZ=.TRUE.: SAME COORDINATES (DEFAULT); .FALSE. DIFFERENT COORDINATES DEFAULT
        LA(I)%SC_OPTION = 0
        IF (LA(I)%LAYSWITCH .EQ. 9) THEN
            LA(I)%UPZ = .FALSE.
            LA(I)%LAYSWITCH = 0
        ENDIF
        IF (LA(I)%LAYSWITCH .EQ. 0) THEN
            WRITE (*, *) '    READING PARAMETERS FOR GRID LAYER ID', LA(I)%ID
        ENDIF
    ENDDO

    CLOSE(666)

    !.... PROCESSING DEPENDENT PARAMETERS FOR TOP LAYER
    !DETERMINE THE NUMBER OF ITS CHILD GRID LAYERS
    COUNT = 0
    DO I = 1, NUM_GRID
        IF (LA(I)%LAYSWITCH.EQ.0 .and. LA(I)%PARENT.EQ.LO%ID) THEN
            COUNT = COUNT + 1
        ENDIF
    ENDDO
    LO%NUM_CHILD = COUNT
    CALL ALLOC(LO, 1)
    ! READ FRICTION COEF. DATA FROM FILE
    IF (LO%FRIC_SWITCH .EQ. 2) CALL READ_FRIC_COEF (LO)

    ! MATCH 2ND-LEVEL GRIDS WITH 1ST-LEVEL GRID
    DO I = 1, NUM_GRID
        IF (LA(I)%LAYSWITCH.EQ.0 .AND. LA(I)%PARENT.EQ.LO%ID) THEN
            IF (LO%LAYCORD.EQ.0 .AND. LA(I)%LAYCORD.EQ.1) THEN
                !SC_OPTION = 0: TRADITIONAL COUPLING SCHEME
                !SC_OPTION = 1: IMPROVED COUPLING SCHEME
                LA(I)%SC_OPTION = 1
                IF (LA(I)%UPZ .EQV. .FALSE.) THEN
                    LA(I)%SC_OPTION = 0
                ENDIF
            ENDIF
            CALL SUBGRID_MATCHING(LO, LA(I))
            CALL ALLOC(LA(I), 2)
            LA(I)%DT = LO%DT / 2.0        !TENTATIVE VALUE
            ! READ FRICTION COEF. DATA FROM FILE
            IF (LA(I)%FRIC_SWITCH .EQ. 2) CALL READ_FRIC_COEF (LA(I))
            !DETERMINE THE NUMBER OF ITS CHILD GRID LAYERS
            COUNT = 0
            DO K = 1, NUM_GRID
                IF (LA(K)%LAYSWITCH.EQ.0 .AND.                        &
                        LA(K)%PARENT.EQ.LA(I)%ID) THEN
                    COUNT = COUNT + 1
                ENDIF
            ENDDO
            LA(I)%NUM_CHILD = COUNT
        ENDIF
    ENDDO

    ! MATCH 3 - 12TH LEVEL GRIDS WITH 2ND-LEVEL GRIDS
    NUM_LEVEL = NUM_GRID + 1
    DO KL = 2, NUM_LEVEL
        DO I = 1, NUM_GRID
            IF (LA(I)%LAYSWITCH.EQ.0 .AND. LA(I)%LEVEL.EQ.KL) THEN
                DO J = 1, NUM_GRID
                    IF (LA(J)%LAYSWITCH.EQ.0 .AND.                    &
                            LA(J)%PARENT.EQ.LA(I)%ID) THEN
                        IF (LA(I)%LAYCORD.EQ.0 .AND.                    &
                                LA(J)%LAYCORD.EQ.1) THEN
                            !SC_OPTION = 0: TRADITIONAL COUPLING SCHEME
                            !SC_OPTION = 1: IMPROVED COUPLING SCHEME
                            LA(J)%SC_OPTION = 1
                            IF (LA(J)%UPZ .EQV. .FALSE.) THEN
                                LA(I)%SC_OPTION = 0
                            ENDIF
                        ENDIF
                        CALL SUBGRID_MATCHING(LA(I), LA(J))
                        CALL ALLOC(LA(J), KL + 1)
                        LA(J)%DT = LA(I)%DT / 2.0        !TENTATIVE VALUE
                        !READ FRICTION COEF. DATA FROM FILE
                        IF (LA(J)%FRIC_SWITCH .EQ. 2) THEN
                            CALL READ_FRIC_COEF (LA(J))
                        ENDIF
                        !DETERMINE THE NUMBER OF ITS CHILD GRID LAYERS
                        COUNT = 0
                        DO K = 1, NUM_GRID
                            IF (LA(K)%LAYSWITCH.EQ.0 .AND.                &
                                    LA(K)%PARENT.EQ.LA(J)%ID) THEN
                                COUNT = COUNT + 1
                            ENDIF
                        ENDDO
                        LA(J)%NUM_CHILD = COUNT
                    ENDIF
                ENDDO
            ENDIF
        ENDDO
    ENDDO

    RETURN
END


!----------------------------------------------------------------------
SUBROUTINE GET_INI_SURF (LO, LA, INI_SURF, WAVE_INFO, FAULT_INFO, &
        LANDSLIDE_INFO)
    !......................................................................
    !DESCRIPTION:
    !	  #. OBTAIN INITIAL FREE SURFACE DISPLACEMENT FROM FAULT MODEL,
    !	     CUSTOMIZED DATA FILE OR LANDSLIDE MODEL;
    !	  #. INTERPOLATE FREE SURFACE DISPLACEMENT INTO NESTED GRID LAYERS;
    !	  #. INI_SURF =
    !			0: USE OKADA'S FAULT MODEL TO CALCULATE DEFORMATION
    !			1: USE AN EXTERNAL FILE TO DETERMINE INITIAL SURFACE
    !			2: USE INCIDENT WAVE MODEL TO DETERMINE INITIAL SURFACE
    !			3: USE SUBMARINE LANDSLIDE MODEL
    !			4: USE MULTIPLE FAULTS + LANDSLIDE (REQUIRE FAULT_MULTI.CTL)
    !			9: USE MANSINHA AND SMYLIES' MODEL TO CALCULATE DEFORMATION
    !	  #. FAULT MODELS ARE CALLED IN THIS SUBROUTINE
    !INPUT:
    !	  #. GRID INFORMATION, FAULT PARAMETERS
    !OUTPUT:
    !	  #. INITIAL WATER SURFACE DISPLACEMENTS OF ALL GRID LAYERS
    !     #. INITIAL SURFACE DISPLACEMENT IS SAVED IN INI_SURFACE.DAT
    !     #. SEAFLOOR DISPLACEMENTS ARE SAVED IN DEFORM_SEGXX.DAT
    !NOTES:
    !     #. CREATED INITIALLY BY TOM LOGAN (ARSC,2005)
    !     #. UPDATED ON DEC 2005 (XIAOMING WANG, CORNELL UNIV.)
    !     #. UPDATED ON SEP17 2006 (XIAOMING WANG, CORNELL UNIV.)
    !     #. UPDATED ON NOV 21 2008 (XIAOMING WANG, GNS)
    !----------------------------------------------------------------------
    USE LAYER_PARAMS
    USE WAVE_PARAMS
    USE FAULT_PARAMS
    USE LANDSLIDE_PARAMS
    TYPE (LAYER) :: LO
    TYPE (LAYER), DIMENSION(NUM_GRID) :: LA
    TYPE (WAVE) :: WAVE_INFO
    TYPE (FAULT), DIMENSION(NUM_FLT) :: FAULT_INFO
    TYPE (LANDSLIDE) :: LANDSLIDE_INFO
    COMMON /CONS/ ELMAX, GRAV, PI, R_EARTH, GX, EPS, ZERO, ONE, NUM_GRID, &
            NUM_FLT, V_LIMIT, RAD_DEG, RAD_MIN

    SELECT CASE (INI_SURF)
    CASE (0)
        !GENERATE DEFORMATION PROFILE FROM BUILT-IN FAULT MODEL
        !REF.: OKADA (1985)
        CALL GET_FLOOR_DEFORM (LO, LA, FAULT_INFO, 0.0)
    CASE (1)
        !LOAD CUSTOMIZED WATER SURFACE DISPLACEMENT FROM A FILE
        CALL READ_INI_SURFACE (LO, LA, FAULT_INFO)
    CASE (2)
        CALL READ_WAVE (WAVE_INFO)
    CASE (3)
        CALL READ_LANDSLIDE (LO, LANDSLIDE_INFO)
    CASE (4)
        CALL GET_FLOOR_DEFORM (LO, LA, FAULT_INFO, 0.0)
        CALL READ_LANDSLIDE (LO, LANDSLIDE_INFO)
    CASE (9)
        !GENERATE DEFORMATION PROFILE FROM BUILT-IN FAULT MODEL
        !REF.: MANSINHA AND SMYLIE (1971)
        CALL GET_FLOOR_DEFORM (LO, LA, FAULT_INFO, 0.0)
    END SELECT

    !.....WRITE INITIAL CONDITION INTO DATA FILE NAMED "INI_SURFACE.DAT"
    CALL WRITE_INI (LO)

    RETURN
END


!----------------------------------------------------------------------
SUBROUTINE GET_MULTIFAULT_PARAMETERS (LO, FLT)
    !......................................................................
    !DESCRIPTION:
    !	  #. OBTAIN FAULT PARAMETERS FOR SINGLE/MULTIPLE FAULT;
    !	  #. FAULT_MULTI.CTL IS REQUIRED IF TOTAL NUMBER OF FAULT PLANES
    !		 IS LARGER THAN 1
    !INPUT:
    !	  #. COMCOT.CTL AND FAULT_MULTI.CTL IF REQUIRED;
    !OUTPUT:
    !	  #. FAULT PARAMETERS FOR ALL FAULT PLANES INCLUDED;
    !NOTES:
    !     #. CREATED ON DEC 18, 2008 (XIAOMING WANG, GNS)
    !     #. UPDATED ON DEC 21 2008 (XIAOMING WANG, GNS)
    !----------------------------------------------------------------------
    USE LAYER_PARAMS
    USE FAULT_PARAMS
    TYPE (LAYER) :: LO
    TYPE (FAULT), dimension(NUM_FLT) :: FLT
    REAL TIME, TEMP(LO%NX)
    INTEGER NUM_FLT
    CHARACTER(LEN = 200) :: line, line1, line2, line3
    CHARACTER(LEN = 200) :: dump, tmp, tmpname, fname
    INTEGER :: POS
    COMMON /CONS/ ELMAX, GRAV, PI, R_EARTH, GX, EPS, ZERO, ONE, NUM_GRID, &
            NUM_FLT, V_LIMIT, RAD_DEG, RAD_MIN
    DATA OSIXTY/0.016666666667/, BIG/-999./

    !*      WRITE(*,*) '    MULTI-FAULTING CONFIGURATION IS IMPLEMENTED...'
    OPEN(UNIT = 23, FILE = 'fault_multi.ctl', STATUS = 'OLD', IOSTAT = ISTAT)
    IF (ISTAT /=0) THEN
        PRINT *, "ERROR:: CAN'T OPEN CONFIG FILE FAULT_MULTI.CTL; EXITING."
        STOP
    END IF

    !----------------------------------------------
    ! READING FAULT PARAMETERS FOR EACH SEGMENT
    !----------------------------------------------
    READ (23, '(8/)')
    !----------------------------------------
    !  READING PARAMETERS FOR EACH FAULT SEGMENT
    !----------------------------------------
    DO K = 2, FLT(1)%NUM_FLT
        WRITE (*, *) '    READING PARAMETERS FOR FAULT SEGMENT', K
        READ (23, '(3/)')
        READ (23, '(49X,F30.9)') FLT(K)%T0            !  RUPTURING TIME OF THIS FAULT PLANE
        READ (23, '(49X,I30)')   FLT(K)%SWITCH        !  OPTION OF OBTAINING DEFORMATION: 0-FAULT MODEL; 1-DATA FILE;
        READ (23, '(49X,F30.9)') FLT(K)%HH            !  FOCAL DEPTH (UNIT: METER)
        READ (23, '(49X,F30.9)') FLT(K)%L            !  LENGTH OF SOURCE AREA (UNIT: METER)
        READ (23, '(49X,F30.9)') FLT(K)%W            !  WIDTH OF SOURCE AREA (UNIT: METER)
        READ (23, '(49X,F30.9)') FLT(K)%D            !  DISLOCATION (UNIT: METER)
        READ (23, '(49X,F30.9)') FLT(K)%TH            !  (=THETA) STRIKE DIRECTION (UNIT: DEGREE)
        READ (23, '(49X,F30.9)') FLT(K)%DL            !  (=DELTA) DIP ANGLE (UNIT : DEGREE)
        READ (23, '(49X,F30.9)') FLT(K)%RD            !  (=LAMDA) SLIP ANGLE (UNIT: DEGREE)
        READ (23, '(49X,F30.9)') FLT(K)%YO            !  ORIGIN OF COMPUTATION (LATITUDE :DEGREE)
        READ (23, '(49X,F30.9)') FLT(K)%XO            !  ORIGIN OF COMPUTATION (LONGITUDE:DEGREE)
        READ (23, '(49X,F30.9)') FLT(K)%Y0            !  EPICENTER (LATITUDE :DEGREE)
        READ (23, '(49X,F30.9)') FLT(K)%X0            !  EPICENTER (LONGITUDE:DEGREE)
        READ (23, '(A)')         LINE                !  NAME OF DEFORMATION DATA FILE
        READ (23, '(49X,I30)')   FLT(K)%FS            !  FORMAT OF DEFORMATION DATA FILE: 0-OLD COMCOT FORMAT;1-MOST;2-XYZ;
        POS = INDEX(LINE, ':')
        IF (POS>0) THEN
            FLT(K)%DEFORM_NAME = TRIM(LINE(POS + 1:200))
        ELSE
            FLT(K)%DEFORM_NAME = 'ini_surface.dat'
        ENDIF
        LINE = ''
        SN = SIN(RAD_DEG * FLT(K)%DL)
        CS = COS(RAD_DEG * FLT(K)%DL)
        IF (ABS(SN) .LT. EPS) FLT(K)%DL = FLT(K)%DL + GX
        IF (ABS(CS) .LT. EPS) FLT(K)%DL = FLT(K)%DL + GX
        !	     IF (SN .EQ. 0.0) FLT(K)%DL = FLT(K)%DL+EPS
        !	     IF (CS .EQ. 0.0) FLT(K)%DL = FLT(K)%DL+EPS
        FLT(K)%NUM_FLT = FLT(1)%NUM_FLT
        FLT(K)%XO = FLT(1)%XO
        FLT(K)%YO = FLT(1)%YO
    ENDDO
    CLOSE(23)

    RETURN
END

!----------------------------------------------------------------------
SUBROUTINE READ_MULTIFAULT_DATA (LO, FLT)
    !......................................................................
    !DESCRIPTION:
    !	  #. OBTAIN FAULT PARAMETERS FOR MULTIPLE FAULT SEGMENTS;
    !	  #. PARAMETERS FOR FAULT SEGMENTS ARE OBTAINED FROM AN EXTERNAL
    !	     DATA FILE GIVEN AT LINE 40 IN COMCOT.CTL;
    !	  #. THE DATA FILE CONTAINS ALL THE INFORMATION FOR EACH SEGMENT;
    !		 EACH ROW FOR ONE SEGMENT: TIME,LON,LAT,L,W,H,THETA,DELTA,LAMBDA,SLIP;
    !	  #. TO USE THIS FUNCTION, INPUT 999 AT LINE 26 IN COMCOT.CTL;
    !INPUT:
    !	  #. PARAMETER DATA FILE;
    !OUTPUT:
    !	  #. FAULT PARAMETERS FOR ALL FAULT PLANES INCLUDED;
    !NOTES:
    !     #. CREATED ON APR 09, 2009 (XIAOMING WANG, GNS)
    !	  #. UPDATED ON APR09 2009 (XIAOMING WANG, GNS)
    !		 1. ADD SUPPORT ON IMPORTING FAULT PARAMETERS FOR MULTIPLE
    !			FAULT SEGMENTS FROM A DATA FILE;
    !----------------------------------------------------------------------
    USE LAYER_PARAMS
    USE FAULT_PARAMS
    TYPE (LAYER) :: LO
    TYPE (FAULT), dimension(NUM_FLT) :: FLT
    REAL TIME, TEMP(LO%NX)
    INTEGER NUM_FLT, COUNT
    CHARACTER(LEN = 200) :: line, line1, line2, line3
    CHARACTER(LEN = 200) :: dump, tmp, tmpname, fname
    INTEGER :: RSTAT
    COMMON /CONS/ ELMAX, GRAV, PI, R_EARTH, GX, EPS, ZERO, ONE, NUM_GRID, &
            NUM_FLT, V_LIMIT, RAD_DEG, RAD_MIN
    DATA OSIXTY/0.016666666667/, BIG/-999./
    RSTAT = 0
    !*      WRITE(*,*) '    MULTI-FAULTING CONFIGURATION IS IMPLEMENTED...'
    OPEN(UNIT = 23, FILE = FLT(1)%DEFORM_NAME, STATUS = 'OLD', IOSTAT = ISTAT)
    IF (ISTAT /=0) THEN
        PRINT *, "ERROR:: CAN'T OPEN FAULT PARAMETER DATA FILE; EXITING."
        STOP
    END IF

    !.....DETERMINE THE TOTAL NUMBER OF FAULT SEGMENTS
    COUNT = -1
    DO WHILE (RSTAT == 0)
        COUNT = COUNT + 1
        READ (23, *, IOSTAT = RSTAT) T1, T2, T3, T4, T5, T6, T7, T8, T9, T10
    ENDDO
    FLT(1)%NUM_FLT = COUNT
    REWIND(23)
    K = 1
    WRITE (*, *) '    READING PARAMETERS FOR FAULT SEGMENT ', K, ' TO ', COUNT
    !----------------------------------------
    !  READING PARAMETERS FOR EACH FAULT SEGMENT
    !----------------------------------------
    DO K = 1, FLT(1)%NUM_FLT
        READ (23, *) FLT(K)%T0, FLT(K)%X0, FLT(K)%Y0, FLT(K)%L, &
                FLT(K)%W, FLT(K)%HH, FLT(K)%TH, FLT(K)%DL, &
                FLT(K)%RD, FLT(K)%D
        IF (K.EQ.1) THEN
            SN = SIN(RAD_DEG * FLT(K)%DL)
            CS = COS(RAD_DEG * FLT(K)%DL)
            IF (ABS(SN) .LT. EPS) FLT(K)%DL = FLT(K)%DL + GX
            IF (ABS(CS) .LT. EPS) FLT(K)%DL = FLT(K)%DL + GX
        ENDIF
        IF (K.GT.1) THEN
            FLT(K)%SWITCH = FLT(1)%SWITCH
            SN = SIN(RAD_DEG * FLT(K)%DL)
            CS = COS(RAD_DEG * FLT(K)%DL)
            IF (ABS(SN) .LT. EPS) FLT(K)%DL = FLT(K)%DL + GX
            IF (ABS(CS) .LT. EPS) FLT(K)%DL = FLT(K)%DL + GX
            FLT(K)%NUM_FLT = FLT(1)%NUM_FLT
            FLT(K)%DEFORM_NAME = FLT(1)%DEFORM_NAME
            FLT(K)%FS = FLT(1)%FS
            FLT(K)%XO = FLT(1)%XO
            FLT(K)%YO = FLT(1)%YO
        ENDIF
    ENDDO
    CLOSE(23)

    RETURN
END


!----------------------------------------------------------------------
SUBROUTINE GET_LANDSLIDE_PARAMETERS (LO, LS)
    !......................................................................
    !DESCRIPTION:
    !	  #. OBTAIN ADDITIONAL PARAMETERS FOR LANDSLIDE CONFIGURATION;
    !	  #. THESE ADDITIONAL PARAMETERS ARE USED TO DETERMINE WATER DEPTH
    !	     VARIATIONS VIA WATTS ET AL (2003)'S LANDSLIDE THEORY;
    !	  #. LANDSLIDE.CTL IS REQUIRED IF THE OPTION IN LANDSLIDE SECTION
    !		 IN COMCOT.CTL IS LARGER THAN 1
    !INPUT:
    !	  #. COMCOT.CTL AND LANDSLIDE.CTL IF REQUIRED;
    !OUTPUT:
    !	  #. ADDITIONAL LANDSLIDE PARAMETERS FOR LANDSLIDE CONFIGURATION;
    !NOTES:
    !     #. CREATED ON FEB 13, 2008 (XIAOMING WANG, GNS)
    !     #. UPDATED ON ???
    !----------------------------------------------------------------------
    USE LAYER_PARAMS
    USE LANDSLIDE_PARAMS
    TYPE (LAYER) :: LO
    TYPE (LANDSLIDE) :: LS
    REAL T0, T1
    COMMON /CONS/ ELMAX, GRAV, PI, R_EARTH, GX, EPS, ZERO, ONE, NUM_GRID, &
            NUM_FLT, V_LIMIT, RAD_DEG, RAD_MIN
    DATA OSIXTY/0.016666666667/, BIG/-999./

    !----------------------------------------------
    ! READING PARAMETERS FOR BUILT-IN SLIDING MODEL
    !----------------------------------------------
    !*      WRITE(*,*) '    MULTI-FAULTING CONFIGURATION IS IMPLEMENTED...'
    OPEN(UNIT = 23, FILE = 'landslide.ctl', STATUS = 'OLD', IOSTAT = ISTAT)
    IF (ISTAT /=0) THEN
        PRINT *, "ERROR:: CAN'T OPEN CONFIG FILE LANDSLIDE.CTL; EXITING."
        STOP
    END IF

    READ (23, '(8/)')
    WRITE (*, *) '    READING PARAMETERS FOR LAND SLIDE CONFIGURATION'
    READ (23, '(3/)')
    READ (23, '(49X,F30.9)') T0                !  LAND SLIDE STARTING TIME (SECONDS)
    READ (23, '(49X,F30.9)') T1                !  LAND SLIDE ENDING TIME (SECONDS)
    READ (23, '(49X,F30.9)') LS%XS                !  X COORD OF STARTING LOCATION (CENTER OF MASS)
    READ (23, '(49X,F30.9)') LS%YS                !  Y COORD OF STARTING LOCATION (CENTER OF MASS)
    READ (23, '(49X,F30.9)') LS%XE                !  X COORD OF STOPPING LOCATION (CENTER OF MASS)
    READ (23, '(49X,F30.9)') LS%YE                !  Y COORD OF STOPPING LOCATION (CENTER OF MASS)
    READ (23, '(49X,F30.9)') LS%SLOPE            !  TYPICAL SLOPE ANGLE ALONG SLIDING PATH (DEGREE)
    READ (23, '(49X,F30.9)') LS%A                !  LENGTH OF SLIDING VOLUME (IN METERS ALONG PATH)
    READ (23, '(49X,F30.9)') LS%B                !  WIDTH OF SLIDING VOLUME (IN METERS CROSS PATH)
    READ (23, '(49X,F30.9)') LS%THICKNESS        !  TYPICAL THICKNESS OF SLIDE VOLUME (IN METERS)
    CLOSE(23)

    LS%DURATION = T1 - T0
    LS%NT = NINT((T1 - T0) / LO%DT) + 1

    ALLOCATE(LS%T(LS%NT))
    LS%T = 0.0

    DO K = 1, LS%NT
        LS%T(K) = (K - 1.0) * LO%DT + T0
    ENDDO

    WRITE (*, *) 'T0=', T0
    WRITE (*, *) 'T1=', T1
    WRITE (*, *) 'NT=', LS%NT
    WRITE (*, *) 'T(1)=', LS%T(1)
    WRITE (*, *) 'T(NT)=', LS%T(LS%NT)
    WRITE (*, *) 'SLOPE=', LS%SLOPE
    WRITE (*, *) 'THICKNESS=', LS%THICKNESS

    RETURN
END

!----------------------------------------------------------------------
SUBROUTINE DX_CALC (LO)
    !......................................................................
    !DESCRIPTION:
    !	  #. CALCULATE GRID SIZE AND X,Y COORDINATES OF 1ST-LEVEL GRIDS
    !		 FOR 'SQUARE' GRID CELLS WHEN SPHERICAL COORDINATE IS ADOPTED,
    !		 DESIGNED FOR DISPERSION IMPROVEMENT PURPOSE;
    !	  #. GRID_SWITCH  - FLAG ONLY FOR SPHERICAL COORDINATES
    !         0 - CREATE A 'SQUARE' GRID CELL IN SPHERICAL COORDINATE,
    !			  I.E., LENGTH OF DX = LENGTH OF DY;
    !		  1 - CREATE A 'NORMAL' GRID CELL IN SPHERICAL COORDINATE,
    !			  I.E., DX = DY IN ARC MINUTES, BUT LENGTH ARE DIFFERENT;
    !     #. *** HERE, LO%PARENT IS TEMPORARILY USED FOR TEST PURPOSE:
    !            =  0: 'SQUARE' GRID CELL WILL BE CREATED FOR LO
    !			 = -1: 'NORMAL' GRID CELL WILL BE CREATED FOR LO
    !NOTE:
    !     #. CREATED ON SEP 18 2006 (XIAOMING WANG, CORNELL UNIV.)
    !	  #. UPDATED ON DEC.17 2008 (XIAOMING WANG, GNS)
    !	  #. UPDATED ON JAN03 2009 (XIAOMING WANG, GNS)
    !----------------------------------------------------------------------
    USE LAYER_PARAMS
    TYPE (LAYER) :: LO, LA
    REAL X, Y, X0, Y0, DX_ARC
    REAL, ALLOCATABLE :: YTMP(:), DEL_Y(:)
    INTEGER GRID_SWITCH
    COMMON /CONS/ ELMAX, GRAV, PI, R_EARTH, GX, EPS, ZERO, ONE, NUM_GRID, &
            NUM_FLT, V_LIMIT, RAD_DEG, RAD_MIN


    !.....TENTATIVE VALUES
    LO%DY = LO%DX
    LO%REL_SIZE = 1
    LO%REL_TIME = 1
    !.....IF THE CARTESIAN COORDINATE IS ADOPTED,
    !     CALCULATE THE GRID DIMENSION, X AND Y COORDINATES;
    IF (LO%LAYCORD.EQ.1) THEN
        LO%NX = NINT((LO%X_END - LO%X_START) / LO%DX) + 1
        LO%NY = NINT((LO%Y_END - LO%Y_START) / LO%DY) + 1
        ALLOCATE(LO%X(LO%NX))
        ALLOCATE(LO%Y(LO%NY))
        ALLOCATE(LO%DEL_X(LO%NX))
        ALLOCATE(LO%DEL_Y(LO%NY))
        DO I = 1, LO%NX
            LO%X(I) = LO%X_START + (I - 1) * LO%DX
        END DO
        DO J = 1, LO%NY
            LO%Y(J) = LO%Y_START + (J - 1) * LO%DY
        END DO
        LO%DEL_X(:) = LO%DX
        LO%DEL_Y(:) = LO%DY
        !SPHERICAL COORDINATES, FOR FACTS INPUT
        IF (LO%BC_TYPE.EQ.3) THEN
            ALLOCATE(LO%CXY(LO%NX, LO%NY, 2))
            LO%CXY = 0.0
            DO I = 1, LO%NX
                DO J = 1, LO%NY
                    CALL COORD_CONVERT (LO%X(I), LO%Y(J), &
                            LO%CXY(I, J, 1), LO%CXY(I, J, 2), LO%XO, LO%YO, 1)
                ENDDO
            ENDDO
        ENDIF
    ENDIF

    !.....IF SPHERICAL COORDINATE IS IMPLEMENTED,
    !     CALCULATE THE GRID DIMENSION, X AND Y COORDINATES;
    !.....IF GRID_SWITCH = 0, GRID SIZE IN Y DIRECTION WILL BE ADJUSTED
    !	  ACCORDING TO LATITUDE SO THAT 'SQUARE' GRID CELLS WILL BE CREATED
    !	  IN SPHERICAL COORDINATES;

    !.....GRID_SWITCH  - FLAG ONLY FOR SPHERICAL COORDINATES
    !         0 - CREATE A 'SQUARE' GRID CELL IN SPHERICAL COORDINATE,
    !			  I.E., LENGTH OF DX = LENGTH OF DY;
    !		  1 - CREATE A 'NORMAL' GRID CELL IN SPHERICAL COORDINATE,
    !			  I.E., DX = DY IN ARC MINUTES, BUT LENGTH ARE DIFFERENT;
    GRID_SWITCH = 0
    IF (LO%PARENT .EQ. -1) GRID_SWITCH = 1 !FOR TEST PURPOSE

    IF (LO%LAYCORD .EQ. 0) THEN
        ! WHEN SQUARE GRID IS REQUIRED
        IF (GRID_SWITCH.EQ.0) THEN
            !CONVERT MINUTES TO DEGREES
            DX = LO%DX / 60.0
            DY = LO%DY / 60.0
            LO%NX = NINT((LO%X_END - LO%X_START) / DX) + 1
            ALLOCATE(LO%X(LO%NX))
            ALLOCATE(LO%DEL_X(LO%NX))
            DO I = 1, LO%NX
                LO%X(I) = (I - 1) * DX + LO%X_START
            END DO
            LO%DEL_X(:) = LO%DX
            !CREATE 'NON-UNIFORM' GRID SIZE IN Y DIRECTION (LATITUDE)
            NY = NINT((LO%Y_END - LO%Y_START) / DY) + 1
            ALLOCATE(YTMP(5 * NY))
            ALLOCATE(DEL_Y(5 * NY))
            YTMP = 0.0
            DEL_Y = 0.0

            K = 1
            YTMP(1) = LO%Y_START
            DO WHILE (YTMP(K).LE.LO%Y_END)
                ANG_K = YTMP(K) * RAD_DEG
                DEL_Y(K) = DX * COS(ANG_K)
                DY = DX * COS(ANG_K + 0.5 * DEL_Y(K) * RAD_DEG)
                YTMP(K + 1) = YTMP(K) + DY
                K = K + 1
            END DO
            LO%NY = K - 1
            ALLOCATE(LO%Y(LO%NY))
            ALLOCATE(LO%DEL_Y(LO%NY))
            LO%Y(:) = YTMP(1:LO%NY)
            LO%DEL_Y(:) = DEL_Y(1:LO%NY) * 60.0
            LO%XO = LO%X(1)
            LO%YO = LO%Y(1)
            !WHEN SQUARE GRID IS NOT REQUIRED
        ELSE
            DX = LO%DX / 60.0
            DY = LO%DY / 60.0
            LO%NX = NINT((LO%X_END - LO%X_START) / DX) + 1
            LO%NY = NINT((LO%Y_END - LO%Y_START) / DY) + 1
            ALLOCATE(LO%X(LO%NX))
            ALLOCATE(LO%Y(LO%NY))
            ALLOCATE(LO%DEL_X(LO%NX))
            ALLOCATE(LO%DEL_Y(LO%NY))
            DO I = 1, LO%NX
                LO%X(I) = LO%X_START + (I - 1) * DX
            END DO
            DO J = 1, LO%NY
                LO%Y(J) = LO%Y_START + (J - 1) * DY
            END DO
            LO%DEL_X(:) = LO%DX
            LO%DEL_Y(:) = LO%DY
            LO%XO = LO%X(1)
            LO%YO = LO%Y(1)
        ENDIF
    ENDIF

    DEALLOCATE(YTMP, DEL_Y, STAT = ISTAT)

    RETURN
END


!----------------------------------------------------------------------
SUBROUTINE SUBGRID_MATCHING (LO, LA)
    !......................................................................
    !DESCRIPTION:
    !     #. CALCULATE GRID DIMENSION AND COORDINATES OF GRID LAYER LA AND
    !		 ITS POSITION IN ITS PARENT LAYER LO
    !	  #. ARRAYS RELATED TO DIMENSION ARE ALLOCATED HERE
    !	  #. LA%UPZ =
    !			.TRUE. - PARENT GRID, LO, AND CHILD GRID, LA, ADOPT
    !					 THE SAME COORDINATE SYSTEM;
    !			.FALSE. - PARENT GRID, LO, AND CHILD GRID, LA, ADOPT
    !					  DIFFERENT COORDINATE SYSTEM;
    !	  #. SC_OPTION: COUPLING SCHEME BETWEEN SPHERICAL AND CARTESIAN
    !			 = 0: TRADITIONAL COUPLING SCHEME BETWEEEN SPH AND CART;
    !			 = 1: IMPROVED COUPLING SCHEME BETWEEN SPH AND CART;
    !INPUT:
    !     LO: PARENT GRID LAYER
    !OUTPUT:
    !     LA: CURRENT GRID LAYER
    !NOTE:
    !     #. CREATED ON NOV 05 2008 (XIAOMING WANG, GNS)
    !     #. UPDATED ON JAN05 2008 (XIAOMING WANG)
    !	  #. UPDATED ON APR03 2009 (XIAOMING WANG)
    !		 1. IMPROVE COUPLING SCHEME BETWEEN SPHERICAL AND CARTESIAN
    !----------------------------------------------------------------------
    USE LAYER_PARAMS
    TYPE (LAYER) :: LO, LA
    REAL SOUTH_LAT, DX_ARC
    REAL LAT, LON, LAT0, LON0, X, Y, X0, Y0
    COMMON /CONS/ ELMAX, GRAV, PI, R_EARTH, GX, EPS, ZERO, ONE, NUM_GRID, &
            NUM_FLT, V_LIMIT, RAD_DEG, RAD_MIN

    WRITE (*, *) '    GENERATING NESTED GRIDS IN LAYER', LO%ID

    !.....DETERMINE TIME STEP SIZE OF CHILD GRID
    !*	  LA%REL_TIME = LA%REL_SIZE
    !*	  LA%DT=LO%DT/LA%REL_SIZE

    !.....DETERMINE POSITION INDICES OF CHILD GRID IN ITS PARENT GRID LAYER
    IS = 2
    IE = LO%NX - 1
    JS = 2
    JE = LO%NY - 1

    DO K = IS, IE
        IF (LA%X_START.GE.(LO%X(K - 1) + LO%X(K)) / 2.0 .AND.            &
                LA%X_START.LT.(LO%X(K) + LO%X(K + 1)) / 2.0) LA%CORNERS(1) = K + 1
        IF (LA%X_END.GE.(LO%X(K - 1) + LO%X(K)) / 2.0 .AND.                &
                LA%X_END.LT.(LO%X(K) + LO%X(K + 1)) / 2.0) LA%CORNERS(2) = K - 1
    ENDDO
    DO K = JS, JE
        IF (LA%Y_START.GE.(LO%Y(K - 1) + LO%Y(K)) / 2.0 .AND.            &
                LA%Y_START.LT.(LO%Y(K) + LO%Y(K + 1)) / 2.0) LA%CORNERS(3) = K + 1
        IF (LA%Y_END.GE.(LO%Y(K - 1) + LO%Y(K)) / 2.0 .AND.                &
                LA%Y_END.LT.(LO%Y(K) + LO%Y(K + 1)) / 2.0) LA%CORNERS(4) = K - 1
    ENDDO

    !.....DETERMINE THE DIMENSION OF CHILD GRID LAYER
    IF (LO%LAYCORD .EQ. LA%LAYCORD) THEN
        LA%NX = (LA%CORNERS(2) - LA%CORNERS(1) + 1) * LA%REL_SIZE + 1
        LA%NY = (LA%CORNERS(4) - LA%CORNERS(3) + 1) * LA%REL_SIZE + 1
        ALLOCATE(LA%X(LA%NX))
        ALLOCATE(LA%Y(LA%NY))
        ALLOCATE(LA%DEL_X(LA%NX))
        ALLOCATE(LA%DEL_Y(LA%NY))
        LA%X = 0.0
        LA%Y = 0.0
        LA%DEL_X = 0.0
        LA%DEL_Y = 0.0
    ENDIF

    !DETERMINE GRID SIZE AND X,Y COORDINATES OF CHILD GRID LAYER: LA
    !WHEN BOTH LO AND LA ADOPT CARTESIAN COORDINATES
    IF (LO%LAYCORD.EQ.1 .AND. LA%LAYCORD.EQ.1) THEN
        LA%DX = LO%DX / DBLE(LA%REL_SIZE)
        LA%DY = LO%DY / DBLE(LA%REL_SIZE)
        XS = 0.5 * (LO%X(LA%CORNERS(1)) + LO%X(LA%CORNERS(1) - 1)) - LA%DX / 2.0
        YS = 0.5 * (LO%Y(LA%CORNERS(3)) + LO%Y(LA%CORNERS(3) - 1)) - LA%DY / 2.0
        DO I = 1, LA%NX
            LA%X(I) = (I - 1) * LA%DX + XS
        ENDDO
        DO J = 1, LA%NY
            LA%Y(J) = (J - 1) * LA%DY + YS
        ENDDO
        LA%DEL_X(:) = LA%DX
        LA%DEL_Y(:) = LA%DY
    ENDIF

    !WHEN BOTH LO AND LA USE SPHERICAL COORDINATES
    IF (LO%LAYCORD .EQ. 0) THEN
        IF (LA%LAYCORD .EQ. 0) THEN
            LA%DX = LO%DX / DBLE(LA%REL_SIZE)
            LA%DY = LO%DY / DBLE(LA%REL_SIZE)
            LA%DEL_X(:) = LA%DX
            LA%DEL_Y(:) = LA%DY
            DX = LA%DX / 60.0  !CONVERT MINUTES TO DEGREES
            XS = 0.5 * (LO%X(LA%CORNERS(1)) + LO%X(LA%CORNERS(1) - 1)) - DX / 2.0
            DO I = 1, LA%NX
                LA%X(I) = (I - 1) * DX + XS
            ENDDO

            JS = LA%CORNERS(3)
            JE = LA%CORNERS(4)
            DY = LO%DEL_Y(JS - 1) / DBLE(LA%REL_SIZE)
            LA%SOUTH_LAT = 0.5 * (LO%Y(JS) + LO%Y(JS - 1)) - 0.5 * DY / 60.0
            LA%Y(1) = LA%SOUTH_LAT
            LA%DEL_Y(1) = DY
            DO J = JS, JE
                DY = LO%DEL_Y(J) / DBLE(LA%REL_SIZE)
                YS = 0.5 * (LO%Y(J) + LO%Y(J - 1))
                KS = (J - JS) * LA%REL_SIZE + 1
                DO K = 1, LA%REL_SIZE
                    LA%DEL_Y(KS + K) = DY
                    LA%Y(KS + K) = YS + (K - 0.5) * DY / 60.0
                ENDDO
            ENDDO
            !			WRITE(*,*) LA%NY,LA%DEL_Y(1),LA%DEL_Y(NINT(LA%NY/2.0)),LA%DEL_Y(LA%NY)
            !*!CALCULATE POSITION AND PARAMETERS REQUIRED FOR DATA COMMUNICATION
            !*!*BETWEEN LO AND LA
        ENDIF
    ENDIF

    !WHEN LO USES SPHERICAL COORDINATES AND LA USES CARTESIAN COORDINATES
    IF (LO%LAYCORD .EQ. 0) THEN
        IF (LA%LAYCORD .EQ. 1) THEN
            !GRID SIZE IN DEGREES
            DX = LO%DX / 60.0 / DBLE(LA%REL_SIZE)
            DY = LO%DEL_Y(LA%CORNERS(3)) / 60.0 / DBLE(LA%REL_SIZE)

            LA%SOUTH_LAT = 0.5 * (LO%Y(LA%CORNERS(3))                    &
                    + LO%Y(LA%CORNERS(3) - 1)) - DY / 2.0

            !ADJUSTED POSITION IN DEGREES
            XS = 0.5 * (LO%X(LA%CORNERS(1)) + LO%X(LA%CORNERS(1) - 1)) - DX / 2.0
            XE = 0.5 * (LO%X(LA%CORNERS(2)) + LO%X(LA%CORNERS(2) + 1)) - DX / 2.0
            YS = 0.5 * (LO%Y(LA%CORNERS(3)) + LO%Y(LA%CORNERS(3) - 1)) - DY / 2.0
            YE = 0.5 * (LO%Y(LA%CORNERS(4)) + LO%Y(LA%CORNERS(4) + 1)) - DY / 2.0

            LA%NX = (LA%CORNERS(2) - LA%CORNERS(1) + 1) * LA%REL_SIZE + 1
            LA%NY = (LA%CORNERS(4) - LA%CORNERS(3) + 1) * LA%REL_SIZE + 1
            ALLOCATE(LA%X(LA%NX))
            ALLOCATE(LA%Y(LA%NY))
            ALLOCATE(LA%XT(LA%NX))
            ALLOCATE(LA%YT(LA%NY))
            ALLOCATE(LA%DEL_X(LA%NX))
            ALLOCATE(LA%DEL_Y(LA%NY))
            LA%X = 0.0
            LA%Y = 0.0
            LA%XT = 0.0
            LA%YT = 0.0
            LA%DEL_X = 0.0
            LA%DEL_Y = 0.0

            CALL COORD_CONVERT (LA%X(LA%NX), LA%Y(1), XE, YS, XS, YS, 0)
            CALL COORD_CONVERT (LA%X(1), LA%Y(LA%NY), XS, YE, XS, YS, 0)
            CALL COORD_CONVERT (LA%X(1), LA%Y(1), XS, YS, XS, YS, 0)
            XLEN = LA%X(LA%NX) - LA%X(1)
            YLEN = LA%Y(LA%NY) - LA%Y(1)
            !			WRITE(*,*) LA%X(1),LA%X(LA%NX),LA%Y(1),LA%Y(LA%NY),XLEN,YLEN

            !*			!GRID SIZE IN METERS, SQUARE GRID CELL (LA%DX=LA%DY)
            LA%DX = XLEN / (LA%NX - 1)
            LA%DY = YLEN / (LA%NY - 1)
            LA%DEL_X(:) = LA%DX
            LA%DEL_Y(:) = LA%DY
            ! X,Y COORDINATES IN METERS
            DO I = 2, LA%NX
                LA%X(I) = (I - 1) * LA%DX + LA%X(1)
            ENDDO
            DO J = 2, LA%NY
                LA%Y(J) = (J - 1) * LA%DY + LA%Y(1)
            ENDDO
            ! X,Y COORDINATES IN DEGREES (CAUSION: COORD NOT EXACT)
            DO I = 1, LA%NX
                LA%XT(I) = (I - 1) * (XE - XS) / (LA%NX - 1) + XS
            ENDDO
            DO J = 1, LA%NY
                LA%YT(J) = (J - 1) * (YE - YS) / (LA%NY - 1) + YS
            ENDDO

            !CALCULATE POSITION AND PARAMETERS REQUIRED FOR DATA COMMUNICATION
            !*BETWEEN LO AND LA
            !***********DETERMINE IJ POSITION OF LAYER LA GRIDS IN LAYER LO*********
            !***********FOR INTERPOLATION FROM LO TO LA ***
            IF (LA%SC_OPTION .EQ. 1) THEN
                ALLOCATE(LA%POS(LA%NX, LA%NY, 2))
                ALLOCATE(LA%CXY(LA%NX, LA%NY, 4))
                LA%POS = 0
                LA%CXY = 0.0
                IMIN = LO%NX
                IMAX = 1
                JMIN = LO%NY
                JMAX = 1
                !...........DETERMINE IJ POSITION OF LA GRID IN LO
                !NATURAL ORIGIN (LOWER-LEFT CORNER GRID) IN DEGREES
                LAT0 = YS
                LON0 = XS
                !NATURAL ORIGIN (LOWER-LEFT CORNER GRID) IN METERS
                X0 = LA%X(1)
                Y0 = LA%Y(1)
                DO I = 1, LA%NX
                    DO J = 1, LA%NY
                        ! CONVERT UTM TO LATTIUDE AND LONGITUDE
                        CALL COORD_CONVERT (LA%X(I), LA%Y(J), LON, LAT, &
                                LON0, LAT0, 1)
                        KI = 0
                        KJ = 0
                        DO K = 2, LO%NX - 1
                            IF (LON.GE.LO%X(K) .AND. LON.LT.LO%X(K + 1)) KI = K
                        ENDDO
                        DO K = 2, LO%NY - 1
                            IF (LAT.GE.LO%Y(K) .AND. LAT.LT.LO%Y(K + 1)) KJ = K
                        ENDDO
                        LA%POS(I, J, 1) = KI
                        LA%POS(I, J, 2) = KJ

                        IF (KI.GT.IMAX) IMAX = KI
                        IF (KI.LT.IMIN) IMIN = KI
                        IF (KJ.GT.JMAX) JMAX = KJ
                        IF (KJ.LT.JMIN) JMIN = KJ

                        IF (KI.GE.1 .AND. KI.LT.LO%NX) THEN
                            IF (KJ.GE.1 .AND. KJ.LT.LO%NY) THEN
                                DELTA_X = LO%X(KI + 1) - LO%X(KI)
                                DELTA_Y = LO%Y(KJ + 1) - LO%Y(KJ)
                                CX = (LON - LO%X(KI)) / DELTA_X
                                CY = (LAT - LO%Y(KJ)) / DELTA_Y
                                !COEF OF LOWER LEFT CORNER
                                LA%CXY(I, J, 1) = (1.0 - CX) * (1.0 - CY)
                                !COEF OF LOWER RIGHT CORNER
                                LA%CXY(I, J, 2) = (CX) * (1.0 - CY)
                                !COEF OF UPPER LEFT CORNER
                                LA%CXY(I, J, 3) = (1.0 - CX) * (CY)
                                !COEF OF UPPER RIGHT CORNER
                                LA%CXY(I, J, 4) = (CX) * (CY)
                            ENDIF
                        ENDIF
                    ENDDO
                ENDDO
                LA%CORNERS(1) = IMIN
                LA%CORNERS(2) = IMAX
                LA%CORNERS(3) = JMIN
                LA%CORNERS(4) = JMAX
                !			WRITE (*,*) IMIN,IMAX,JMIN,JMAX
            ENDIF
        ENDIF
    ENDIF
    !	  WRITE (*,*) LA%X(1),LA%X(LA%NX),LA%Y(1),LA%Y(LA%NY)

    RETURN
END


!----------------------------------------------------------------------
SUBROUTINE CR_CHECK (LO, LA)
    !......................................................................
    !DESCRIPTION:
    !     #. CHECK COURANT CONDITION AND ADJUST TIME STEP SIZE OF LO
    !		 IF NECESSARY AND DETERMINE TIME STEP SIZES OF ALL SUB-LEVEL
    !		 GRID LAYERS AND THE TIME RATIOS OF LO TO LA.
    !	  #. TIME STEP SIZE IS DETERMINED BY THE MAXIMUM WATER DEPTH OF A
    !	     GRID LAYER WITH COURANT NUMBER SET TO 0.5; IF NONLINEAR SWE IS
    !		 IMPLEMENTED, COURANT NUMBER IS SET TO 0.4;
    !INPUT:
    !	  #. WATER DEPTH AND GRID SIZE OF LO AND LA, LO%DT
    !OUTPUT:
    !	  #. TIME STEP SIZE DT OF LO IF ADJUSTMENT IS REQUIRED
    !	  #. TIME STEP SIZE RATIO OF LO TO LA
    !NOTE:
    !     #. CREATED ON SEP 18 2006 (XIAOMING WANG, CORNELL UNIV.)
    !     #. UPDATED ON DEC. 20 2008 (XIAOMING WANG, GNS)
    !----------------------------------------------------------------------
    USE LAYER_PARAMS
    TYPE (LAYER) :: LO, LA(NUM_GRID)
    REAL H_MAX, SOUTH_LAT, LAT_MAX, DX, DY, DT, DT1, DEL_X, CR
    INTEGER IR
    COMMON /CONS/ ELMAX, GRAV, PI, R_EARTH, GX, EPS, ZERO, ONE, NUM_GRID, &
            NUM_FLT, V_LIMIT, RAD_DEG, RAD_MIN

    WRITE (*, *) '    VALIDATING AND DETERMINING TIME STEP SIZES......'

    H_MAX = GX
    G = GRAV
    CR_LIMIT = 0.5

    DT = LO%DT
    !.....CHECK COURANT CONDITION FOR 1ST-LEVEL GRIDS
    DO I = 1, LO%NX
        DO J = 1, LO%NY
            IF (LO%H(I, J) .GT. H_MAX) H_MAX = LO%H(I, J)
        ENDDO
    ENDDO

    IF (LO%LAYCORD .EQ. 0) THEN
        !CONVERT TO ARC LENGTH (M) IF SPHERICAL COORD.
        LAT_MAX = AMAX1(ABS(LO%Y(1)), ABS(LO%Y(LO%NY))) * RAD_DEG
        DX = R_EARTH * COS(LAT_MAX) * (LO%DX * RAD_MIN)
        DY = R_EARTH * (LO%DY * RAD_MIN)
    ELSE
        DX = LO%DX
        DY = LO%DY
    ENDIF

    DEL_X = AMIN1(DX, DY) !FIND THE SMALLER BETWEEN DX AND DY

    IF (LO%LAYSWITCH .EQ. 0) THEN
        CR = LO%DT / (DEL_X / SQRT(GRAV * H_MAX))
        CR_LIMIT = 0.5
        IF (LO%LAYGOV.EQ.1 .OR. LO%LAYGOV.EQ.3) CR_LIMIT = 0.35
        IF (CR .GT. CR_LIMIT) THEN
            WRITE (*, *) '       WARNING: CR TOO LARGE, DT ADJUSTED!'
            DT = CR_LIMIT * DEL_X / SQRT(GRAV * H_MAX)
        ENDIF
        IF (DT.LE.LO%DT) LO%DT = DT
    ENDIF

    !.....ASSIGN DEPENDENT VARIABLES
    IF (LO%LAYCORD.EQ.1) THEN
        LO%RX = LO%DT / LO%DX
        LO%RY = LO%DT / LO%DY
        LO%GRX = GRAV * LO%RX
        LO%GRY = GRAV * LO%RY
    ENDIF

    !.....CHECK COURANT CONDITION FOR 2ND-LEVEL GRIDS
    DO K = 1, NUM_GRID
        IF (LA(K)%LAYSWITCH.EQ.0 .AND. LA(K)%PARENT.EQ.LO%ID) THEN
            H_MAX = GX
            DO I = 1, LA(K)%NX
                DO J = 1, LA(K)%NY
                    IF (LA(K)%H(I, J) .GT. H_MAX) H_MAX = LA(K)%H(I, J)
                ENDDO
            ENDDO
            IF (LA(K)%LAYCORD .EQ. 0) THEN
                !CONVERT TO ARC LENGTH (M) IF SPHERICAL COORD.
                LAT_MAX = AMAX1(ABS(LA(K)%Y(1)), &
                        ABS(LA(K)%Y(LA(K)%NY))) * RAD_DEG
                DX = R_EARTH * COS(LAT_MAX) * (LA(K)%DX * RAD_MIN)
                DY = R_EARTH * (LA(K)%DY * RAD_MIN)
            ELSE
                DX = LA(K)%DX
                DY = LA(K)%DY
            ENDIF
            CR_LIMIT = 0.5
            IF (LA(K)%LAYGOV.EQ.1 .OR. LA(K)%LAYGOV.EQ.3)            &
                    CR_LIMIT = 0.35
            DEL_X = AMIN1(DX, DY) !FIND THE SMALLER BETWEEN DX AND DY
            DT = CR_LIMIT * DEL_X / SQRT(GRAV * H_MAX)
            IF (DT .GE. LO%DT) THEN
                LA(K)%DT = LO%DT
                LA(K)%REL_TIME = 1
            ELSE
                IR = FLOOR(LO%DT / DT) + 1
                LA(K)%REL_TIME = IR
                LA(K)%DT = LO%DT / IR
            ENDIF
            !			LA(K)%REL_TIME = 2
            !			LA(K)%DT = LO%DT/LA(K)%REL_TIME
            !!			ASSIGN DEPENDENT VARIABLES
            IF (LA(K)%LAYCORD.EQ.1) THEN
                LA(K)%RX = LA(K)%DT / LA(K)%DX
                LA(K)%RY = LA(K)%DT / LA(K)%DY
                LA(K)%GRX = GRAV * LA(K)%RX
                LA(K)%GRY = GRAV * LA(K)%RY
            ENDIF
        ENDIF
    ENDDO

    ! 3 - 12TH LEVEL GRIDS
    NUM_LEVEL = NUM_GRID + 1
    DO KL = 3, NUM_LEVEL
        DO I = 1, NUM_GRID
            IF (LA(I)%LAYSWITCH.EQ.0 .AND. LA(I)%LEVEL.EQ.KL - 1) THEN
                DO J = 1, NUM_GRID
                    IF (LA(J)%LAYSWITCH.EQ.0 .AND.                    &
                            LA(J)%PARENT.EQ.LA(I)%ID) THEN
                        H_MAX = GX
                        DO KI = 1, LA(J)%NX
                            DO KJ = 1, LA(J)%NY
                                IF (LA(J)%H(KI, KJ) .GT. H_MAX)            &
                                        H_MAX = LA(J)%H(KI, KJ)
                            ENDDO
                        ENDDO
                        IF (LA(J)%LAYCORD .EQ. 0) THEN
                            !CONVERT TO ARC LENGTH (M) IF SPHERICAL COORD.
                            LAT_MAX = AMAX1(ABS(LA(J)%Y(1)), &
                                    ABS(LA(J)%Y(LA(J)%NY))) * RAD_DEG

                            DX = R_EARTH * COS(LAT_MAX) * (LA(J)%DX * RAD_MIN)
                            DY = R_EARTH * (LA(J)%DY * RAD_MIN)
                        ELSE
                            DX = LA(J)%DX
                            DY = LA(J)%DY
                        ENDIF

                        CR_LIMIT = 0.5
                        IF (LA(J)%LAYGOV.EQ.1 .OR. LA(J)%LAYGOV.EQ.3)    &
                                CR_LIMIT = 0.35
                        !FIND THE SMALLER BETWEEN DX AND DY
                        DEL_X = AMIN1(DX, DY)
                        DT = CR_LIMIT * DEL_X / SQRT(GRAV * H_MAX)
                        IF (DT .GE. LA(I)%DT) THEN
                            LA(J)%DT = LA(I)%DT
                            LA(J)%REL_TIME = 1
                        ELSE
                            IR = FLOOR(LA(I)%DT / DT) + 1
                            LA(J)%REL_TIME = IR
                            LA(J)%DT = LA(I)%DT / IR
                        ENDIF
                        !					 LA(J)%REL_TIME = 2
                        !					 LA(J)%DT = LA(I)%DT/LA(J)%REL_TIME
                        !!					 ASSIGN DEPENDENT VARIABLES
                        IF (LA(J)%LAYCORD.EQ.1) THEN
                            LA(J)%RX = LA(J)%DT / LA(J)%DX
                            LA(J)%RY = LA(J)%DT / LA(J)%DY
                            LA(J)%GRX = GRAV * LA(J)%RX
                            LA(J)%GRY = GRAV * LA(J)%RY
                        ENDIF
                    ENDIF
                ENDDO
            ENDIF
        ENDDO
    ENDDO

    RETURN
END


!----------------------------------------------------------------------
SUBROUTINE COORD_CONVERT (X_UTM, Y_UTM, LON, LAT, OLON, OLAT, OPTION)
    !......................................................................
    !DESCRIPTION:
    !     #. MAKE CONVERSION BETWEEN UTM AND LATITUDE AND LONGITUDE
    !	  #. BE CAREFUL NOT TO CROSS DIFFERENT ZONES (INCL. THE EQUATOR);
    !	  #. OPTION:
    !			= 0: CONVERT LATITUDE/LONGITUDE TO UTM (X,Y);
    !			= 1: CONVERT UTM (X,Y) TO LATITUDE/LONGITUDE;
    !INPUT:
    !	  #. LATITUDE AND LONGITUDE FOR OPTION = 0;
    !	  #. X_UTM,Y_UTM,OLAT,OLON FOR OPTION = 1; OLAT AND OLON ARE USED TO
    !		 IDENTIFY THE UTM ZONE;
    !OUTPUT:
    !	  #. UTM COORDINATES, X (EASTING) AND Y (NORTHING) WITH FALSE
    !		 NORTHING AND EASTING CORRECTION FOR OPTION = 0;
    !	  #. LAT/LON COORDINATES FOR OPTION = 0;
    !NOTE:
    !     #. CREATED ON JAN 05 2009 (XIAOMING WANG, GNS)
    !     #. UPDATED ON JAN 15 2009 (XIAOMING WANG, GNS)
    !	  #. UPDATED ON MAR 10 2009 (XIAOMING WANG, GNS)
    !		 1. ADD CONVERSION FROM UTM TO SPHERICAL
    !----------------------------------------------------------------------
    REAL X_UTM, Y_UTM, X, Y, X0, Y0, LAT, LON, LAT0, LON0, OLON, OLAT
    REAL FALSE_NORTHING, FALSE_EASTING, ZONE_WIDTH
    INTEGER NUM_ZONE, I, J, M, N, OPTION
    REAL ZC(60)
    COMMON /CONS/ ELMAX, GRAV, PI, R_EARTH, GX, EPS, ZERO, ONE, NUM_GRID, &
            NUM_FLT, V_LIMIT, RAD_DEG, RAD_MIN

    LON0 = 0.0
    LAT0 = 0.0
    !DEFINE CENTRAL MERIDIAN OF UTM ZONES
    !NOTE: THE INDEX NO. DOESN'T CORRESPOND TO TRUE UTM ZONE NUMBER
    NUM_ZONE = 60        ! TOTAL NUMBER OF UTM ZONES
    ZONE_WIDTH = 6.0  ! WIDTH OF A UTM ZONE
    ZC(1) = 3.0        !CENTRAL MERIDIAN OF THE FIRST UTM ZONE !-177.0
    DO I = 2, NUM_ZONE
        ZC(I) = ZC(1) + (I - 1) * ZONE_WIDTH
    ENDDO
    !FIND THE UTM ZONE (CENTRAL MERIDIAN) OF INPUT COORDINATES
    KI = 1
    DO I = 1, NUM_ZONE
        IF (OLON.GE.(ZC(I) - 3.0) .AND. OLON.LT.(ZC(I) + 3.0)) THEN
            LON0 = ZC(I)
        ENDIF
    ENDDO

    IF (OLAT.LT.ZERO) THEN
        FALSE_NORTHING = 10000000.0
    ELSE
        FALSE_NORTHING = 0.0
    ENDIF
    FALSE_EASTING = 500000.0

    IF (OPTION.EQ.0) THEN
        X_UTM = 0.0
        Y_UTM = 0.0
        X = 0.0
        Y = 0.0

        CALL SPH_TO_UTM (X, Y, LON, LAT, LON0, LAT0)

        X_UTM = X + FALSE_EASTING
        Y_UTM = Y + FALSE_NORTHING
    ENDIF

    IF (OPTION.EQ.1) THEN
        X = X_UTM - FALSE_EASTING
        Y = Y_UTM - FALSE_NORTHING

        CALL UTM_TO_SPH (X, Y, LON, LAT, LON0, LAT0)

    ENDIF

    RETURN
END


!----------------------------------------------------------------------
SUBROUTINE UTM_TO_SPH (X, Y, LON, LAT, LON0, LAT0)
    !......................................................................
    !DESCRIPTION:
    !     #. MAPPING A POINT ON A PLANE ONTO THE ELLIPSOID SURFACE;
    !	  #. USE REVERSE TRANSVERSE MERCATOR PROJECTION;
    !     #. CONVERT UTM (NO FALSE NORTHING/EASTING) TO LATITUDE/LONGITUDE;
    !     #. UTM COORDINATES RELATIVE TO USER-DEFINED NATURAL ORIGIN
    !INPUT:
    !     X: X COORDINATE/EASTING IN METERS RELATIVE TO NATURAL ORIGIN
    !     Y: Y COORDINATE/NORTHING IN METERS RELATIVE TO NATURAL ORIGIN
    !     LAT0: LATITUDE OF NATURAL ORIGIN IN DEGREES (USER-DEFINED)
    !     LON0: LONGITUDE OF NATURAL ORIGIN IN DEGREES (USER-DEFINED)
    !OUTPUT:
    !     LAT: LATITUDE IN DEGREES
    !     LON: LONGITUDE IN DEGREES
    !REFERENCES:
    !	  #. SNYDER, J.P. (1987). MAP PROJECTIONS - A WORKING MANUAL.
    !                          USGS PROFESSIONAL PAPER 1395
    !	  #. POSC SPECIFICATIONS 2.2
    !     #. ELLIPSOIDAL DATUM: WGS84
    !NOTES:
    !     CREATED ON DEC22 2008 (XIAOMING WANG, GNS)
    !	  UPDATED ON JAN05 2009 (XIOAMING WANG, GNS)
    !----------------------------------------------------------------------
    REAL X, Y, XF, YF, LATIN, LONIN, LAT0, LON0, LAT, LON, LT0, LN0
    REAL E, ES, F2, F4, F6, RHO, RHO0, M, N, NU, NU0
    REAL LT1, NU1, RHO1, T1, C1, D, D1, CS1, E1, MU1, S1
    REAL TMP, TMP0
    REAL CS, SN, CS0, SN0, SIN1, TN, TN0, POLE, P, S, C, T
    REAL K0, K1, K2, K3, K4, K5, K10, K20, K30, K40, K50
    COMMON /CONS/ ELMAX, GRAV, PI, R_EARTH, GX, EPS, ZERO, ONE, NUM_GRID, &
            NUM_FLT, V_LIMIT, RAD_DEG, RAD_MIN

    POLE = PI / 2.0 - EPS      !AVOID SINGULARITY AT POLES
    !.....CONSTANTS BASED ON WGS84 DATUM
    A = 6378137.0
    B = 6356752.3142
    K0 = 0.9996

    E = 0.081819190928906           ! E = SQRT(1-B**2/A**2)
    ES = 0.006739496756587          ! ES = E**2/(1-E**2)
    N = 0.001679220389937           ! N = (A-B)/(A+B)

    F2 = 0.006694380004261        ! F2=E**2
    F4 = 0.00004481472364144701   ! F4=E**4
    F6 = 0.0000003000067898417773 ! F6=E**6

    !.....FALSE EASTING AND NORTHING
    XF = 0.0
    YF = 0.0
    !*	  XF = 500000.0							  ! FOR NORTH HEMISPHERE
    !*	  IF (LATIN .LT. 0.0) YF = 10000000.0     ! FOR SOUTH HEMISPHERE
    !.....CONVERT DEGREES TO RADIAN
    LT0 = LAT0 * RAD_DEG
    LN0 = LON0 * RAD_DEG

    IF (LT0 .GT. POLE) LT0 = POLE
    IF (LT0 .LT. -POLE) LT0 = -POLE

    S0 = A * ((1.0 - F2 / 4.0 - 3.0 * F4 / 64.0 - 5.0 * F6 / 256.) * LT0                &
            - (3. * F2 / 8.0 + 3.0 * F4 / 32.0 + 45.0 * F6 / 1024.0) * SIN(2.0 * LT0)    &
            + (15.0 * F4 / 256.0 + 45.0 * F6 / 1024.0) * SIN(4.0 * LT0)            &
            - (35.0 * F6 / 3072.0) * SIN(6.0 * LT0))

    S1 = S0 + (Y - YF) / K0
    MU1 = S1 / A / (1.0 - F2 / 4.0 - 3.0 * F4 / 64.0 - 5.0 * F6 / 256.0)
    E1 = (1.0 - SQRT(1.0 - F2)) / (1.0 + SQRT(1.0 - F2))
    LT1 = MU1 + (3.0 * E1 / 2.0 - 27.0 * E1**3 / 32.0) * SIN(2.0 * MU1)            &
            + (21.0 * E1**2 / 16.0 - 55.0 * E1**4 / 32.0) * SIN(4.0 * MU1)        &
            + (151.0 * E1**3 / 96.0) * SIN(6.0 * MU1)                        &
            + (1097.0 * E1**4 / 512.0) * SIN(8.0 * MU1)

    IF (LT1 .GT. POLE) LT1 = POLE
    IF (LT1 .LT. -POLE) LT1 = -POLE

    TMP1 = SQRT(1.0 - F2 * SIN(LT1)**2)
    NU1 = A / TMP1
    RHO1 = A * (1.0 - F2) / TMP1**3
    T1 = TAN(LT1)**2
    C1 = ES * COS(LT1)**2
    D = (X - XF) / NU1 / K0

    LAT = LT1 - NU1 * TAN(LT1) / RHO1 * (D**2 / 2.0                        &
            - (5.0 + 3.0 * T1 + 10.0 * C1 - 4.0 * C1**2 - 9.0 * ES) * D**4 / 24.0    &
            + (61.0 + 90.0 * T1 + 298.0 * C1 + 45.0 * T1**2 - 252 * ES            &
                    - 3.0 * C1**2) * D**6 / 720.0)

    LON = LN0 + 1.0 / COS(LT1) * (D - (1.0 + 2.0 * T1 + C1) * D**3 / 6.0        &
            + (5.0 - 2.0 * C1 + 28.0 * T1 - 3.0 * C1**2 + 8.0 * ES + 24.0 * T1**2)    &
                    * D**5 / 120.0)

    !     CONVERT UNITS FROM RADIAN TO DEGREES
    LAT = LAT * 180.0 / PI
    LON = LON * 180.0 / PI
    !	  WRITE(*,*) X,Y

    RETURN
END

!----------------------------------------------------------------------
SUBROUTINE SPH_TO_UTM (X, Y, LONIN, LATIN, LON0, LAT0)
    !......................................................................
    !DESCRIPTION:
    !     #. MAPPING A POINT ON THE ELLIPSOID SURFACE ONTO A PLANE;
    !	  #. USE TRANSVERSE MERCATOR PROJECTION
    !     #. CONVERT LATITUDE/LONGITUDE TO UTM (NO FALSE NORTHING/EASTING);
    !     #. UTM COORDINATES RELATIVE TO USER-DEFINED NATURAL ORIGIN
    !INPUT:
    !     LATIN: LATITUDE IN DEGREES
    !     LONIN: LONGITUDE IN DEGREES
    !     LAT0: LATITUDE OF NATURAL ORIGIN IN DEGREES (USER-DEFINED)
    !     LON0: LONGITUDE OF NATURAL ORIGIN IN DEGREES (USER-DEFINED)
    !OUTPUT:
    !     X: X COORDINATE/EASTING IN METERS RELATIVE TO NATURAL ORIGIN
    !     Y: Y COORDINATE/NORTHING IN METERS RELATIVE TO NATURAL ORIGIN
    !REFERENCES:
    !	  #. SNYDER, J.P. (1987). MAP PROJECTIONS - A WORKING MANUAL.
    !                          USGS PROFESSIONAL PAPER 1395
    !	  #. POSC SPECIFICATIONS 2.2
    !     #. ELLIPSOIDAL DATUM: WGS84
    !NOTES:
    !     CREATED ON DEC22 2008 (XIAOMING WANG, GNS)
    !	  UPDATED ON JAN05 2009 (XIOAMING WANG, GNS)
    !----------------------------------------------------------------------
    REAL X, Y, XF, YF, LATIN, LONIN, LAT0, LON0, LAT, LON, LT0, LN0
    REAL E, ES, F2, F4, F6, RHO, RHO0, M, N, NU, NU0
    REAL TMP, TMP0
    REAL CS, SN, CS0, SN0, SIN1, TN, TN0, POLE, P, S, C, T
    REAL K0, K1, K2, K3, K4, K5, K10, K20, K30, K40, K50
    COMMON /CONS/ ELMAX, GRAV, PI, R_EARTH, GX, EPS, ZERO, ONE, NUM_GRID, &
            NUM_FLT, V_LIMIT, RAD_DEG, RAD_MIN

    POLE = PI / 2.0 - EPS      !AVOID SINGULARITY AT POLES
    !.....CONSTANTS BASED ON WGS84 DATUM
    A = 6378137.0
    B = 6356752.3142
    K0 = 0.9996

    E = 0.081819190928906           ! E = SQRT(1-B**2/A**2)
    ES = 0.006739496756587          ! ES = E**2/(1-E**2)
    N = 0.001679220389937           ! N = (A-B)/(A+B)

    F2 = 0.006694380004261        ! F2=E**2
    F4 = 0.00004481472364144701   ! F4=E**4
    F6 = 0.0000003000067898417773 ! F6=E**6

    !.....FALSE EASTING AND NORTHING
    !*	  XF = 0.0
    !*	  YF = 0.0								! FOR NORTH HEMISPHERE
    !*	  XF = 500000.0
    !*	  IF (LATIN .LT. 0.0) YF = 10000000.0   ! FOR SOUTH HEMISPHERE;
    !.....CONVERT DEGREES TO RADIAN
    LAT = LATIN * RAD_DEG
    LON = LONIN * RAD_DEG
    LT0 = LAT0 * RAD_DEG
    LN0 = LON0 * RAD_DEG

    IF (LAT .GT. POLE) LAT = POLE
    IF (LAT .LT. -POLE) LAT = -POLE
    IF (LT0 .GT. POLE) LT0 = POLE
    IF (LT0 .LT. -POLE) LT0 = -POLE

    CS = COS(LAT)
    SN = SIN(LAT)
    TN = SN / CS

    CS0 = COS(LT0)
    SN0 = SIN(LT0)
    TN0 = SN0 / CS0

    TMP = SQRT(1.0 - F2 * SN**2)
    NU = A / TMP

    T = TN**2
    C = ES * CS**2
    P = (LON - LN0) * CS

    S = A * ((1.0 - F2 / 4.0 - 3.0 * F4 / 64.0 - 5.0 * F6 / 256.0) * LAT                &
            - (3.0 * F2 / 8.0 + 3.0 * F4 / 32.0 + 45.0 * F6 / 1024.0) * SIN(2.0 * LAT)    &
            + (15.0 * F4 / 256.0 + 45.0 * F6 / 1024.0) * SIN(4.0 * LAT)            &
            - (35.0 * F6 / 3072.0) * SIN(6.0 * LAT))

    S0 = A * ((1.0 - F2 / 4.0 - 3.0 * F4 / 64.0 - 5.0 * F6 / 256.) * LT0                &
            - (3. * F2 / 8.0 + 3.0 * F4 / 32.0 + 45.0 * F6 / 1024.0) * SIN(2.0 * LT0)    &
            + (15.0 * F4 / 256.0 + 45.0 * F6 / 1024.0) * SIN(4.0 * LT0)            &
            - (35.0 * F6 / 3072.0) * SIN(6.0 * LT0))

    X = K0 * NU * (P + (1.0 - T + C) * P**3 / 6.0 &
            + (5.0 - 18.0 * T + T**2 + 72.0 * C - 58.0 * ES) * P**5 / 120.0)

    Y = K0 * (S - S0 + NU * TN * (P**2 / 2.0 + (5.0 - T + 9.0 * C + 4.0 * C**2) * P**4 / 24.0 &
            + (61.0 - 58.0 * T + T**2 + 600.0 * C - 330.0 * ES) * P**6 / 720.0))

    !*	  X = XF + X
    !*	  Y = YF + Y

    !	  WRITE(*,*) X,Y

    RETURN
END


!----------------------------------------------------------------------
SUBROUTINE READ_INI_SURFACE (LO, LA, FAULT_INFO)
    !......................................................................
    !DESCRIPTION:
    !	  #. READ BATHYMETRY DATA FROM WATER DEPTH FILES, CREATE COMCOT
    !		 GRIDS FOR NUMERICAL SIMULATION AND WRITE THE COMCOT GRID DATA
    !	     INTO DATA FILES (PART OF ORIGINAL BATHYMETRY);
    !NOTES:
    !	  #. LAST REVISE: NOV.10 2008 (XIAOMING WANG, GNS)
    !	  #. UPDATED ON FEB 26 2009 (XIAOMING WANG, GNS)
    !----------------------------------------------------------------------
    USE LAYER_PARAMS
    USE FAULT_PARAMS
    TYPE (LAYER) :: LO
    TYPE (LAYER), DIMENSION(NUM_GRID) :: LA
    TYPE (FAULT), DIMENSION(NUM_FLT) :: FAULT_INFO
    COMMON /CONS/ ELMAX, GRAV, PI, R_EARTH, GX, EPS, ZERO, ONE, NUM_GRID, &
            NUM_FLT, V_LIMIT, RAD_DEG, RAD_MIN

    WRITE (*, *) 'READING WATER SURFACE DISPLACEMENT DATA...'

    !LOAD CUSTOMIZED WATER SURFACE DISPLACEMENT FROM A FILE
    IF (LO%LAYSWITCH.EQ.0 .AND. FAULT_INFO(1)%FS.EQ.0) THEN
        CALL READ_COMCOT_DEFORM (LO, FAULT_INFO(1))
    ENDIF
    IF (LO%LAYSWITCH.EQ.0 .AND. FAULT_INFO(1)%FS.EQ.1) THEN
        CALL READ_MOST_DEFORM (LO, FAULT_INFO(1))
    ENDIF
    IF (LO%LAYSWITCH.EQ.0 .AND. FAULT_INFO(1)%FS.EQ.2) THEN
        CALL READ_XYZ_DEFORM (LO, FAULT_INFO(1))
    ENDIF

    !INTEROLATE WATER SURFACE DEFORMATION TO ALL SUB-GRIDS
    CALL ININTERP(LO, LA)

    !APPLY DISPLACEMENT ONTO ORIGINAL WATER SURFACE
    IF (LO%LAYSWITCH .EQ. 0) THEN
        LO%Z(:, :, 1) = LO%Z(:, :, 1) + LO%DEFORM(:, :)
    ENDIF
    DO K = 1, NUM_GRID
        IF (LA(K)%LAYSWITCH .EQ. 0) THEN
            LA(K)%Z(:, :, 1) = LA(K)%Z(:, :, 1) + LA(K)%DEFORM(:, :)
        ENDIF
    ENDDO

    RETURN
END


!----------------------------------------------------------------------
SUBROUTINE READ_BATHYMETRY (LO, LA)
    !......................................................................
    !DESCRIPTION:
    !	  #. READ BATHYMETRY DATA FROM WATER DEPTH FILES, CREATE COMCOT
    !		 GRIDS FOR NUMERICAL SIMULATION AND WRITE THE COMCOT GRID DATA
    !	     INTO DATA FILES (PART OF ORIGINAL BATHYMETRY);
    !NOTES:
    !	  #. LAST REVISE: NOV.10 2008 (XIAOMING WANG, GNS)
    !	  #. UPDATED ON FEB 26 2009 (XIAOMING WANG, GNS)
    !----------------------------------------------------------------------
    USE LAYER_PARAMS
    TYPE (LAYER) :: LO
    TYPE (LAYER), DIMENSION(NUM_GRID) :: LA
    COMMON /CONS/ ELMAX, GRAV, PI, R_EARTH, GX, EPS, ZERO, ONE, NUM_GRID, &
            NUM_FLT, V_LIMIT, RAD_DEG, RAD_MIN

    WRITE (*, *) 'READING BATHYMETRY DATA...'
    IF (LO%LAYSWITCH .EQ. 0) THEN
        IF (LO%FS .EQ. 0) CALL READ_COMCOT_BATHY(LO)
        IF (LO%FS .EQ. 1) CALL READ_MOST_BATHY(LO)
        IF (LO%FS .EQ. 2) CALL READ_XYZ_BATHY(LO)
        IF (LO%FS .EQ. 3) CALL READ_ETOPO_BATHY(LO)
        !WRITE BATHYMETRY DATA OF COMPUTATIONAL DOMAIN INTO FILE
        CALL BATHY_WRITE (LO)
    END IF
    DO I = 1, NUM_GRID
        IF (LA(I)%LAYSWITCH .EQ. 0) THEN
            IF (LA(I)%FS .EQ. 0) CALL READ_COMCOT_BATHY(LA(I))
            IF (LA(I)%FS .EQ. 1) CALL READ_MOST_BATHY(LA(I))
            IF (LA(I)%FS .EQ. 2) CALL READ_XYZ_BATHY(LA(I))
            IF (LA(I)%FS .EQ. 3) CALL READ_ETOPO_BATHY(LA(I))
            !WRITE BATHYMETRY DATA OF COMPUTATIONAL DOMAIN INTO FILE
            CALL BATHY_WRITE (LA(I))
        END IF
    END DO

    RETURN
END


!----------------------------------------------------------------------
SUBROUTINE READ_COMCOT_BATHY (LO)
    !......................................................................
    !DESCRIPTION:
    !	  #. READ BATHYMETRY DATA WRITTEN IN COMCOT FORMAT
    !NOTES:
    !	  #. LAST REVISE: NOV.18 2008 (XIAOMING WANG)
    !	  #. UPDATED ON DEC 18 2008 (XIAOMING WANG, GNS)
    !----------------------------------------------------------------------
    USE LAYER_PARAMS
    TYPE (LAYER) :: LO
    INTEGER :: ISTAT, IS, JS, I, J
    INTEGER :: LENGTH, RC !, FLAG
    INTEGER  NX, NY
    REAL DX, DY
    REAL, ALLOCATABLE :: H(:, :), TMP(:, :), X(:), Y(:)
    CHARACTER(LEN = 20) FNAME
    COMMON /CONS/ ELMAX, GRAV, PI, R_EARTH, GX, EPS, ZERO, ONE, NUM_GRID, &
            NUM_FLT, V_LIMIT, RAD_DEG, RAD_MIN

    IF (LO%LAYGOV.EQ.0) THEN
        DX = LO%DX / 60.0
        DY = LO%DY / 60.0
    ELSE
        DX = LO%DX
        DY = LO%DY
    ENDIF
    NX = NINT((LO%X_END - LO%X_START) / DX) + 1
    NY = NINT((LO%Y_END - LO%Y_START) / DY) + 1
    ALLOCATE(X(NX))
    ALLOCATE(Y(NY))
    ALLOCATE(H(NX, NY))
    ALLOCATE(TMP(NX, NY))
    X = 0.0
    Y = 0.0
    H = 0.0
    TMP = 0.0
    IF (LO%UPZ) THEN
        !*	     DO I = 1,NX
        !*	        X(I) = LO%X_START + (I-1)*DX
        !*	     END DO
        !*	     DO J = 1,NY
        !*	        Y(J) = LO%Y_START + (J-1)*DY
        !*	     END DO
    ELSE
        DO I = 1, NX
            X(I) = (I - 1) * DX
        END DO
        DO J = 1, NY
            Y(J) = (J - 1) * DY
        END DO
    ENDIF

    IF (LO%ID .EQ. 1) THEN
        IS = 1
        JS = 1
    ELSE
        IS = 2
        JS = 2
    END IF

    WRITE (*, *) '    READING BATHMETRY DATA OF LAYER ID', LO%ID

    OPEN (UNIT = 23, FILE = LO%DEPTH_NAME, STATUS = 'OLD', IOSTAT = ISTAT)
    IF (ISTAT /=0) THEN
        PRINT *, "ERROR:: CAN'T OPEN WATERDEPTH DATA FILE; EXITING."
        STOP
    END IF
    DO J = 1, NY
        READ (23, '(10F9.3)') (H(I, J), I = 1, NX)
    END DO
    CLOSE (23)

    !MAP THE BATHYMETRY DATA ONTO NUMERICAL GRIDS VIA BILINEAR INTERPOLATION
    IF (LO%LEVEL.EQ.1) THEN
        CALL GRID_INTERP (LO%H, LO%X, LO%Y, LO%NX, LO%NY, H, X, Y, NX, NY)
    ELSE
        CALL GRID_INTERP (LO%H(2:LO%NX, 2:LO%NY), LO%X(2:LO%NX), &
                LO%Y(2:LO%NY), LO%NX - 1, LO%NY - 1, H, X, Y, NX, NY)
    ENDIF
    !      WRITE(*,*) L%H(1,1),L%H(L%NX,L%NY)

    IF (LO%PARENT.GE.1) THEN
        !.....INTERPOLATED TO GET BATH VALUE FOR ADDITIONAL COLUMN AND ROW
        LO%H(1, :) = LO%H(2, :) * 2.0 - LO%H(3, :)
        LO%H(:, 1) = LO%H(:, 2) * 2.0 - LO%H(:, 3)
        LO%Y(1) = 2.0 * LO%Y(2) - LO%Y(3)
    END IF

    IF (LO%INI_SWITCH.EQ.3 .OR. LO%INI_SWITCH.EQ.4) THEN
        LO%HT(:, :, 1) = LO%H(:, :)
        LO%HT(:, :, 2) = LO%H(:, :)
    ENDIF

    !*	  CALL PQ_DEPTH (LO)
    DEALLOCATE(H, TMP, X, Y, STAT = ISTAT)

    RETURN
END


!----------------------------------------------------------------------
SUBROUTINE READ_MOST_BATHY (LO)
    !......................................................................
    !DESCRIPTION:
    !	  #. READ BATHYMETRY DATA FORMATTED FOR MOST MODEL
    !NOTES:
    !	  #. CREATED ON OCT 29 2008 (XIAOMING WANG, GNS)
    !	  #. LAST REVISE: NOV.24 2008 (XIAOMING WANG)
    !----------------------------------------------------------------------
    USE LAYER_PARAMS
    TYPE (LAYER) :: LO
    INTEGER :: STAT, IS, JS, I, J, NX, NY
    INTEGER :: LENGTH, RC, POS !, FLAG
    REAL, ALLOCATABLE :: H(:, :), TMP(:, :), X(:), Y(:), YTMP(:)
    !      CHARACTER(LEN) FNAME
    COMMON /CONS/ ELMAX, GRAV, PI, R_EARTH, GX, EPS, ZERO, ONE, NUM_GRID, &
            NUM_FLT, V_LIMIT, RAD_DEG, RAD_MIN

    WRITE (*, *) '    READING MOST-FORMATED BATHMETRY FOR LAYER ID', LO%ID
    OPEN (UNIT = 23, FILE = LO%DEPTH_NAME, STATUS = 'OLD', IOSTAT = ISTAT, &
            FORM = 'FORMATTED')
    IF (ISTAT /=0) THEN
        PRINT *, "ERROR:: CAN'T OPEN WATERDEPTH DATA FILE; EXITING."
        STOP
    END IF
    READ (23, *) NX, NY

    ALLOCATE(X(NX))
    ALLOCATE(Y(NY))
    ALLOCATE(YTMP(NY))
    ALLOCATE(TMP(NX, NY))
    ALLOCATE(H(NX, NY))
    X = 0.0
    Y = 0.0
    YTMP = 0.0
    TMP = 0.0
    H = 0.0

    READ (23, *) (X(I), I = 1, NX)
    READ (23, *) (YTMP(I), I = 1, NY)
    DO J = 1, NY
        READ (23, *) (TMP(I, J), I = 1, NX)
    END DO
    CLOSE (23)

    !.....CONVERT THE FORMAT FROM MOST COORDINATES INTO COMCOT COORDINATES
    ! NOTE: IN MOST DATA, Y POINTING TO THE SOUTH
    !       IN COMCOT, Y POINTING TO THE NORTH
    !!....DATA NEED TO FLIP
    ! FLIP Y COORDINATES
    DO J = 1, NY
        K = NY - J + 1
        Y(K) = YTMP(J)
    END DO
    ! FLIP BATHYMETRY MATRIX
    DO I = 1, NX
        DO J = 1, NY
            K = NY - J + 1
            H(I, K) = TMP(I, J)
        END DO
    END DO
    !      WRITE(*,*) H(1,NY),H(NX,1)

    IF (X(1).EQ.LO%X(1) .AND. Y(1).EQ.LO%Y(LO%NY) .AND.            &
            NX.EQ.LO%NX .AND. NY.EQ.LO%NY) THEN
        LO%H(:, :) = H(:, :)
    ELSE
        !MAP THE BATHYMETRY DATA ONTO NUMERICAL GRIDS VIA BILINEAR INTERPOLATION
        CALL GRID_INTERP (LO%H, LO%X, LO%Y, LO%NX, LO%NY, H, X, Y, NX, NY)
    ENDIF

    IF (LO%INI_SWITCH.EQ.3 .OR. LO%INI_SWITCH.EQ.4) THEN
        LO%HT(:, :, 1) = LO%H(:, :)
        LO%HT(:, :, 2) = LO%H(:, :)
    ENDIF

    !*	  IF (ABS(LO%H_LIMIT).GT.0.00001) CALL DEPTH_LIMIT (LO)
    !.....CALCULATE STILL WATER DEPTH AT VOLUME FLUX LOCATIONS
    !*	  CALL PQ_DEPTH (LO)
    DEALLOCATE(H, TMP, X, Y, YTMP, STAT = ISTAT)

    RETURN
END

!----------------------------------------------------------------------
SUBROUTINE READ_XYZ_BATHY (LO)
    !......................................................................
    !DESCRIPTION:
    !	  #. READ XYZ FORMAT (ASCII) BATHYMETRY DATA;
    !     #. GRIDDED DEFORMATION DATA CONTAINS 3 COLUMNS: X COORDINATES,
    !		 Y COORDINATES, WATERDEPTH (Z);
    !	  #. COORDINATE SYSTEM IS DEFINED SO THAT X POINTING TO THE EAST
    !		 (LONGITUDE) AND Y AXIS POINTING TO THE NORTH (LATITUDE);
    !     #. GRID DATA IS WRITTEN ROW BY ROW (X FIRST) FROM WEST TO EAST,
    !		 FROM SOUTH TO NORTH (OR FOR NORTH TO SOUTH);
    !     #. NODATA TYPE, NAN, IS NOT ALLOWED
    !NOTES:
    !     #. CREATED ON NOV 05 2008 (XIAOMING WANG, GNS)
    !     #. LAST REVISE: NOV.24 2008 (XIAOMING WANG)
    !----------------------------------------------------------------------
    USE LAYER_PARAMS
    TYPE (LAYER) :: LO
    REAL, ALLOCATABLE :: HTMP(:, :), H(:, :)
    REAL, ALLOCATABLE :: XCOL(:), YCOL(:), ZCOL(:)
    REAL, ALLOCATABLE :: X(:), Y(:), XTMP(:), YTMP(:)
    INTEGER      STAT, IS, JS, I, J
    !      INTEGER	   LENGTH, RC, POS !, FLAG
    INTEGER      COUNT
    INTEGER :: RSTAT
    COMMON /CONS/ ELMAX, GRAV, PI, R_EARTH, GX, EPS, ZERO, ONE, NUM_GRID, &
            NUM_FLT, V_LIMIT, RAD_DEG, RAD_MIN
    RSTAT = 0
    WRITE (*, *) '    READING XYZ BATHMETRY DATA FOR LAYER ID', LO%ID
    OPEN (UNIT = 23, FILE = LO%DEPTH_NAME, STATUS = 'OLD', &
            IOSTAT = ISTAT, FORM = 'FORMATTED')
    IF (ISTAT /=0) THEN
        PRINT *, "ERROR:: CAN'T OPEN WATERDEPTH DATA FILE; EXITING."
        STOP
    END IF

    !.....DETERMINE THE LENGTH OF BATHYMETRY DATA FILE
    COUNT = -1
    TEMP = 0.0
    DO WHILE (RSTAT == 0)
        COUNT = COUNT + 1
        READ (23, *, IOSTAT = RSTAT) TEMP1, TEMP2, TEMP3
    ENDDO
    NXY = COUNT
    ALLOCATE(XCOL(NXY))
    ALLOCATE(YCOL(NXY))
    ALLOCATE(ZCOL(NXY))
    XCOL = 0.0
    YCOL = 0.0
    ZCOL = 0.0

    !*!.....READING BATHYMETRY DATA
    REWIND(23)
    DO I = 1, COUNT
        READ (23, *) XCOL(I), YCOL(I), ZCOL(I)
        IF (ZCOL(I)/=ZCOL(I)) ZCOL(I) = 9999.0
        IF (ABS(ZCOL(I)).GE.HUGE(ZCOL(I))) ZCOL(I) = 9999.0
    END DO
    CLOSE (23)

    !<<<  CHECK IF THE DATA IS WRITTEN ROW BY ROW
    !.....DETERMINE GRID DIMENSION: NX,NY
    TMPX = XCOL(1)
    TMPX1 = XCOL(2)
    TMPY = YCOL(1)
    TMPY1 = YCOL(2)
    IF (ABS(TMPX1 - TMPX).GT.EPS .AND. ABS(TMPY1 - TMPY).LT.EPS) THEN
        !*	  IF (TMPX1.NE.TMPX .AND. TMPY1.EQ.TMPY) THEN
        K = 1
        DO WHILE (TMPX1.GT.TMPX)
            K = K + 1
            TMPX1 = XCOL(K)
        ENDDO
        NX = K - 1
        NY = NINT(DBLE(NXY / NX))
        !	     WRITE (*,*) '       GRID DIMENSION OF BATHYMETRY: ', NX,NY
        ALLOCATE(X(NX))
        ALLOCATE(Y(NY))
        ALLOCATE(YTMP(NY))
        ALLOCATE(HTMP(NX, NY))
        ALLOCATE(H(NX, NY))
        X = 0.0
        Y = 0.0
        YTMP = 0.0
        HTMP = 0.0
        H = 0.0

        !.....   OBTAINED X,Y COORDINATES
        X(1:NX) = XCOL(1:NX)
        DO J = 1, NY
            K = (J - 1) * NX + 1
            YTMP(J) = YCOL(K)
        END DO
        !GENERATE GRID DATA
        DO J = 1, NY
            KS = (J - 1) * NX + 1
            KE = (J - 1) * NX + NX
            HTMP(1:NX, J) = ZCOL(KS:KE)
        END DO
    ENDIF
    !>>>>>
    !<<<<<CHECK IF THE DATA IS WRITTEN COLUMN BY COLUMN
    TMPX = XCOL(1)
    TMPX1 = XCOL(2)
    TMPY = YCOL(1)
    TMPY1 = YCOL(2)
    !	  write (*,*) TMPX,TMPX1,TMPY,TMPY1,NXY
    IF (ABS(TMPX1 - TMPX).LT.EPS .AND. ABS(TMPY1 - TMPY).GT.EPS) THEN
        !*	  IF (TMPX1.EQ.TMPX .AND. TMPY1.NE.TMPY) THEN
        K = 1
        DO WHILE (TMPX1.LE.TMPX)
            K = K + 1
            TMPX1 = XCOL(K)
        ENDDO
        NY = K - 1
        !	     WRITE(*,*) NX
        NX = NINT(DBLE(NXY / NY))

        !*	     WRITE (*,*) '       GRID DIMENSION OF BATHYMETRY DATA: ', NX,NY
        ALLOCATE(X(NX))
        ALLOCATE(Y(NY))
        ALLOCATE(XTMP(NX))
        ALLOCATE(YTMP(NY))
        ALLOCATE(HTMP(NX, NY))
        ALLOCATE(H(NX, NY))
        HTMP = 0.0
        X = 0.0
        Y = 0.0
        YTMP = 0.0
        H = 0.0
        !........OBTAINED X,Y COORDINATES
        YTMP(1:NY) = YCOL(1:NY)
        DO I = 1, NX
            K = (I - 1) * NY + 1
            X(I) = XCOL(K)
        END DO
        !GENERATE GRID DATA
        DO I = 1, NX
            KS = (I - 1) * NY + 1
            KE = (I - 1) * NY + NY
            HTMP(I, 1:NY) = ZCOL(KS:KE)
        END DO
    ENDIF
    !>>>>>


    !!....DETERMINE IF THE DATA NEED FLIP
    !     Y COORDINATE IS FROM NORTH TO SOUTH OR FROM SOUTH TO NORTH
    !     IFLIP = 0: FLIP; 1: NO FLIP OPERATION
    IFLIP = 0
    IF (YTMP(NY).LT.YTMP(NY - 1)) IFLIP = 1

    IF (IFLIP .EQ. 1) THEN
        ! FLIP Y COORDINATES
        DO J = 1, NY
            K = NY - J + 1
            Y(K) = YTMP(J)
        END DO
        ! FLIP BATHYMETRY MATRIX
        DO I = 1, NX
            DO J = 1, NY
                K = NY - J + 1
                H(I, K) = HTMP(I, J)
            END DO
        END DO
    ELSE
        Y = YTMP
        H = HTMP
    END IF
    !*      WRITE (*,*) H(1,1),H(NX,NY),ZCOL(1),ZCOL(NXY)
    !	  WRITE (*,*) 'THE CODE REACHES HERE!!!'
    !MAP THE BATHYMETRY DATA ONTO NUMERICAL GRIDS VIA BILINEAR INTERPOLATION
    CALL GRID_INTERP (LO%H, LO%X, LO%Y, LO%NX, LO%NY, H, X, Y, NX, NY)

    !      WRITE(*,*) L%H(1,1),L%H(L%NX,L%NY)

    IF (LO%INI_SWITCH.EQ.3 .OR. LO%INI_SWITCH.EQ.4) THEN
        LO%HT(:, :, 1) = LO%H(:, :)
        LO%HT(:, :, 2) = LO%H(:, :)
    ENDIF

    !	  WRITE (*,*) 'THE CODE finishes the interpolation!!!'

    !.....CALCULATE STILL WATER DEPTH AT DISCHARGE LOCATION P AND Q
    !*	  CALL PQ_DEPTH (LO)
    DEALLOCATE(HTMP, H, STAT = ISTAT)
    DEALLOCATE(XCOL, YCOL, ZCOL, STAT = ISTAT)
    DEALLOCATE(X, Y, XTMP, YTMP, STAT = ISTAT)

    RETURN
END


!----------------------------------------------------------------------
SUBROUTINE READ_ETOPO_BATHY (LO)
    !......................................................................
    !DESCRIPTION:
    !	  #. READ XYZ FORMAT (ASCII) ETOPO BATHYMETRY DATA;
    !     #. GRIDDED DEFORMATION DATA CONTAINS 3 COLUMNS: X COORDINATES,
    !		 Y COORDINATES, WATERDEPTH (Z);
    !	  #. FOR ETOPO BATHYMETRY DATA, LONGITITUDE LARGER THAN 180E, IT
    !		 BECOMES A NEGATIVE VALUE; 3RD COLUMN SHOULD CHANGE SIGN TO
    !		 CONVERT IT TO WATERDEPTH;
    !	  #. COORDINATE SYSTEM IS DEFINED SO THAT X POINTING TO THE EAST
    !		 (LONGITUDE) AND Y AXIS POINTING TO THE NORTH (LATITUDE);
    !     #. GRID DATA IS WRITTEN ROW BY ROW (X FIRST) FROM WEST TO EAST,
    !		 FROM SOUTH TO NORTH (OR FOR NORTH TO SOUTH);
    !     #. NODATA TYPE, NAN, IS NOT ALLOWED
    !NOTES:
    !     #. CREATED ON NOV 05 2008 (XIAOMING WANG, GNS)
    !     #. LAST REVISE: FEB18 2009 (XIAOMING WANG, GNS)
    !----------------------------------------------------------------------
    USE LAYER_PARAMS
    TYPE (LAYER) :: LO
    REAL, ALLOCATABLE :: HTMP(:, :), H(:, :)
    REAL, ALLOCATABLE :: XCOL(:), YCOL(:), ZCOL(:)
    REAL, ALLOCATABLE :: X(:), Y(:), XTMP(:), YTMP(:)
    INTEGER      STAT, IS, JS, I, J
    INTEGER       LENGTH, RC, POS !, FLAG
    INTEGER      COUNT
    COMMON /CONS/ ELMAX, GRAV, PI, R_EARTH, GX, EPS, ZERO, ONE, NUM_GRID, &
            NUM_FLT, V_LIMIT, RAD_DEG, RAD_MIN
    INTEGER :: ISTAT
    INTEGER :: RSTAT
    ISTAT = 0
    RSTAT = 0
    WRITE (*, *) '    READING ETOPO BATHMETRY DATA FOR LAYER ID', LO%ID
    OPEN (UNIT = 23, FILE = LO%DEPTH_NAME, STATUS = 'OLD', &
            IOSTAT = ISTAT, FORM = 'FORMATTED')
    IF (ISTAT /=0) THEN
        PRINT *, "ERROR:: CAN'T OPEN WATERDEPTH DATA FILE; EXITING."
    END IF

    !.....DETERMINE THE LENGTH OF BATHYMETRY DATA FILE
    COUNT = -1
    TEMP = 0.0
    DO WHILE (RSTAT == 0)
        COUNT = COUNT + 1
        READ (23, *, IOSTAT = RSTAT) TEMP1, TEMP2, TEMP3
    ENDDO
    NXY = COUNT
    ALLOCATE(XCOL(NXY))
    ALLOCATE(YCOL(NXY))
    ALLOCATE(ZCOL(NXY))
    XCOL = 0.0
    YCOL = 0.0
    ZCOL = 0.0

    !*!.....READING BATHYMETRY DATA
    REWIND(23)
    DO I = 1, COUNT
        READ (23, *) XCOL(I), YCOL(I), ZCOL(I)
        IF (ZCOL(I)/=ZCOL(I)) ZCOL(I) = 9999.0
        IF (ABS(ZCOL(I)).GE.HUGE(ZCOL(I))) ZCOL(I) = 9999.0
        IF (XCOL(I).LT.0.0) XCOL(I) = XCOL(I) + 360.0
        ZCOL(I) = -ZCOL(I)
    END DO
    CLOSE (23)

    !<<<  CHECK IF THE DATA IS WRITTEN ROW BY ROW
    !.....DETERMINE GRID DIMENSION: NX,NY
    TMPX = XCOL(1)
    TMPX1 = XCOL(2)
    TMPY = YCOL(1)
    TMPY1 = YCOL(2)
    IF (ABS(TMPX1 - TMPX).GE.EPS .AND. ABS(TMPY1 - TMPY).LT.EPS) THEN
        !*	  IF (TMPX1.NE.TMPX .AND. TMPY1.EQ.TMPY) THEN
        K = 1
        DO WHILE (TMPX1.GT.TMPX)
            K = K + 1
            TMPX1 = XCOL(K)
        ENDDO
        NX = K - 1
        NY = NINT(DBLE(NXY / NX))
        !	     WRITE (*,*) '       GRID DIMENSION OF BATHYMETRY: ', NX,NY
        ALLOCATE(X(NX))
        ALLOCATE(Y(NY))
        ALLOCATE(YTMP(NY))
        ALLOCATE(HTMP(NX, NY))
        ALLOCATE(H(NX, NY))
        X = 0.0
        Y = 0.0
        YTMP = 0.0
        HTMP = 0.0
        H = 0.0

        !.....   OBTAINED X,Y COORDINATES
        X(1:NX) = XCOL(1:NX)
        DO J = 1, NY
            K = (J - 1) * NX + 1
            YTMP(J) = YCOL(K)
        END DO
        !GENERATE GRID DATA
        DO J = 1, NY
            KS = (J - 1) * NX + 1
            KE = (J - 1) * NX + NX
            HTMP(1:NX, J) = ZCOL(KS:KE)
        END DO
    ENDIF
    !>>>>>
    !<<<<<CHECK IF THE DATA IS WRITTEN COLUMN BY COLUMN
    TMPX = XCOL(1)
    TMPX1 = XCOL(2)
    TMPY = YCOL(1)
    TMPY1 = YCOL(2)
    !	  write (*,*) TMPX,TMPX1,TMPY,TMPY1,NXY
    IF (ABS(TMPX1 - TMPX).LT.EPS .AND. ABS(TMPY1 - TMPY).GT.EPS) THEN
        !*	  IF (TMPX1.EQ.TMPX .AND. TMPY1.NE.TMPY) THEN
        K = 1
        DO WHILE (TMPX1.LE.TMPX)
            K = K + 1
            TMPX1 = XCOL(K)
        ENDDO
        NY = K - 1
        !	     WRITE(*,*) NX
        NX = NINT(DBLE(NXY / NY))

        !*	     WRITE (*,*) '       GRID DIMENSION OF BATHYMETRY DATA: ', NX,NY
        ALLOCATE(X(NX))
        ALLOCATE(Y(NY))
        ALLOCATE(XTMP(NX))
        ALLOCATE(YTMP(NY))
        ALLOCATE(HTMP(NX, NY))
        ALLOCATE(H(NX, NY))
        HTMP = 0.0
        X = 0.0
        Y = 0.0
        YTMP = 0.0
        H = 0.0
        !........OBTAINED X,Y COORDINATES
        YTMP(1:NY) = YCOL(1:NY)
        DO I = 1, NX
            K = (I - 1) * NY + 1
            X(I) = XCOL(K)
        END DO
        !GENERATE GRID DATA
        DO I = 1, NX
            KS = (I - 1) * NY + 1
            KE = (I - 1) * NY + NY
            HTMP(I, 1:NY) = ZCOL(KS:KE)
        END DO
    ENDIF
    !>>>>>


    !!....DETERMINE IF THE DATA NEED FLIP
    !     Y COORDINATE IS FROM NORTH TO SOUTH OR FROM SOUTH TO NORTH
    !     IFLIP = 0: FLIP; 1: NO FLIP OPERATION
    IFLIP = 0
    IF (YTMP(NY).LT.YTMP(NY - 1)) IFLIP = 1

    IF (IFLIP .EQ. 1) THEN
        ! FLIP Y COORDINATES
        DO J = 1, NY
            K = NY - J + 1
            Y(K) = YTMP(J)
        END DO
        ! FLIP BATHYMETRY MATRIX
        DO I = 1, NX
            DO J = 1, NY
                K = NY - J + 1
                H(I, K) = HTMP(I, J)
            END DO
        END DO
    ELSE
        Y = YTMP
        H = HTMP
    END IF
    !*      WRITE (*,*) H(1,1),H(NX,NY),ZCOL(1),ZCOL(NXY)

    !MAP THE BATHYMETRY DATA ONTO NUMERICAL GRIDS VIA BILINEAR INTERPOLATION
    CALL GRID_INTERP (LO%H, LO%X, LO%Y, LO%NX, LO%NY, H, X, Y, NX, NY)

    !      WRITE(*,*) L%H(1,1),L%H(L%NX,L%NY)

    IF (LO%INI_SWITCH.EQ.3 .OR. LO%INI_SWITCH.EQ.4) THEN
        LO%HT(:, :, 1) = LO%H(:, :)
        LO%HT(:, :, 2) = LO%H(:, :)
    ENDIF

    !.....CALCULATE STILL WATER DEPTH AT DISCHARGE LOCATION P AND Q
    !	  CALL PQ_DEPTH (LO)
    DEALLOCATE(HTMP, H, STAT = ISTAT)
    DEALLOCATE(XCOL, YCOL, ZCOL, STAT = ISTAT)
    DEALLOCATE(X, Y, XTMP, YTMP, STAT = ISTAT)

    RETURN
END

!----------------------------------------------------------------------
SUBROUTINE GRID_INTERP (H, H_X, H_Y, IX, JY, BATH, X, Y, NX, NY)
    !......................................................................
    !DESCRIPTION:
    !	  #. INTERPOLATING THE GRIDDED INPUT DATA ONTO NUMERICAL GRIDS;
    !     #. BILINEAR INTERPOLATION IS IMPLEMENTED;
    !INPUT:
    !	  #. BATH: INPUT GRIDDED DATA;
    !	  #. X, Y: X AND Y COORDINATES OF THE INPUT GRIDDED DATA;
    !	  #. NX, NY: X AND Y GRID DIMENSION OF THE INPUT GRIDDED DATA;
    !	  #. H_X,H_Y: X AND Y COORDINATES OF THE GRID INTERPOLATED FROM
    !		 THE INPUT GRIDDED DATA - 'H';
    !	  #. IX, JY: X AND Y GRID DIMENSION OF 'H';
    !OUTPUT:
    !	  #. H: GRID DATA OBTAINED BY INTERPOLATING 'BATH';
    !NOTES:
    !     #. CREATED ON NOV 05 2008 (XIAOMING WANG, GNS);
    !     #. LAST REVISE: NOV.24 2008 (XIAOMING WANG, GNS);
    !	  #. UPDATED ON MAR 17 2009 (XIAOMING WANG, GNS);
    !		 1. FIX THE PROBLEM WHEN 'H' AND 'BATH' HAVE THE SAME RANGE;
    !----------------------------------------------------------------------
    INTEGER ISTAT, IS, JS, IE, JE, I0, J0, NX, NY
    INTEGER IX, JY, ID
    REAL H(IX, JY), H_X(IX), H_Y(JY)
    REAL TMP(NX, NY), BATH(NX, NY)
    REAL X(NX), Y(NY)
    REAL DELTA_X, DELTA_Y, CX, CY, Z1, Z2, Z3, Z4

    CX = 0.0
    CY = 0.0
    Z1 = 0.0
    Z2 = 0.0
    Z3 = 0.0
    Z4 = 0.0
    H = 0.0

    IS = 1
    JS = 1
    IE = IX
    JE = JY

    !.....BILINEAR INTERPOLATION
    DO J = JS, JE
        DO I = IS, IE
            KI = 0
            KJ = 0
            DO KS = 1, NX - 1
                IF (H_X(I).GE.X(KS) .AND. H_X(I).LT.X(KS + 1)) THEN
                    KI = KS
                END IF
            END DO
            IF (H_X(I).GT.X(NX - 1) .AND. H_X(I).LE.X(NX)) THEN
                KI = NX - 1
            ENDIF

            DO KS = 1, NY - 1
                IF (H_Y(J).GE.Y(KS) .AND. H_Y(J).LT.Y(KS + 1)) THEN
                    KJ = KS
                END IF
            END DO
            IF (H_Y(J).GT.Y(NY - 1) .AND. H_Y(J).LE.Y(NY)) THEN
                KJ = NY - 1
            ENDIF

            IF (KI.GE.1 .AND. KI.LT.NX) THEN
                IF (KJ.GE.1 .AND. KJ.LT.NY) THEN
                    DELTA_X = X(KI + 1) - X(KI)
                    DELTA_Y = Y(KJ + 1) - Y(KJ)
                    CX = (H_X(I) - X(KI)) / DELTA_X
                    CY = (H_Y(J) - Y(KJ)) / DELTA_Y
                    Z1 = BATH(KI, KJ) * (1.0 - CX) * (1.0 - CY)
                    Z2 = BATH(KI + 1, KJ) * (CX) * (1.0 - CY)
                    Z3 = BATH(KI, KJ + 1) * (1.0 - CX) * (CY)
                    Z4 = BATH(KI + 1, KJ + 1) * (CX) * (CY)
                    H(I, J) = Z1 + Z2 + Z3 + Z4
                ENDIF
            ENDIF
        END DO
    END DO

    RETURN
END


!----------------------------------------------------------------------
SUBROUTINE DEPTH_LIMIT (LO)
    !DESCRIPTION:
    !	  #. SETUP VERTICAL WALL BOUNDARY AT SPECIFIED DEPTH CONTOUR BY
    !	     CHANGING WATER DEPTH SHALLOWER THAN H_LIMIT TO LAND
    !NOTE:
    !	  #. CREATED ON OCT 25 2008 (XIAOMING WANG, GNS)
    !----------------------------------------------------------------------
    USE LAYER_PARAMS
    TYPE (LAYER) :: LO

    DO I = 1, LO%NX
        DO J = 1, LO%NY
            IF (LO%H(I, J) .LE. LO%H_LIMIT) THEN
                LO%H(I, J) = -999.0
                IF (LO%INI_SWITCH.EQ.3 .OR. LO%INI_SWITCH.EQ.4) THEN
                    LO%HT(I, J, 1) = -999.0
                    LO%HT(I, J, 2) = -999.0
                END IF
            END IF
        END DO
    END DO

    RETURN
END


!----------------------------------------------------------------------
SUBROUTINE TIDAL_CORRECTION (LO)
    !DESCRIPTION:
    !	  #. SETUP TIDAL LEVEL CORRECTION FOR TSUNAMIS RUNNING OVER HIGH
    !		 TIDAL LEVEL OR LOW TIDAL LEVEL;
    !
    !NOTE:
    !	  #. CREATED ON FEB 26 2008 (XIAOMING WANG, GNS)
    !	  #. UPDATED ON MAR 12 2009 (XIAOMING WANG, GNS)
    !		 1. ADD TREATMENT FOR THOSE LAND AREAS SHOULD NOT BE SUBMERGED
    !			ALTHOUGH BELOW HIGH TIDAL LEVEL;
    !----------------------------------------------------------------------
    USE LAYER_PARAMS
    TYPE (LAYER) :: LO
    REAL TEMP(LO%NX, LO%NY)

    TEMP = LO%H

    LO%H(:, :) = LO%H(:, :) + LO%TIDE_LEVEL
    IF (LO%INI_SWITCH.EQ.3 .OR. LO%INI_SWITCH.EQ.4) THEN
        LO%HT(:, :, 1) = LO%HT(:, :, 1) + LO%TIDE_LEVEL
        LO%HT(:, :, 2) = LO%HT(:, :, 2) + LO%TIDE_LEVEL
    ENDIF
    !	  !SPECIAL TREATMENT
    !	  IF (LO%LAYGOV.EQ.1) THEN
    !		 DO I  = 1,LO%NX
    !		    DO J = 1,LO%NY
    !			   IF (TEMP(I,J).LT.0.0 .AND.							&
    !							TEMP(I,J)+LO%TIDE_LEVEL.GT.0.0) THEN
    !				  LO%Z(I,J,1) = - (TEMP(I,J)+LO%TIDE_LEVEL)
    !				  LO%DZ(I,J,1) = 0.0
    !			   ENDIF
    !		    ENDDO
    !	     ENDDO
    !	  ENDIF

    RETURN
END


!----------------------------------------------------------------------
SUBROUTINE UPDATE_BATH (LO, LA)
    !DESCRIPTION:
    !	  #. UPDATE BATHYMETRY/TOPOGRAPHY TO ACCOUNT FOR THE DEFORMATION
    !		 CAUSED BY EARTHUAKE;
    !	  #. STILL WATER DEPTH AT DISCHARGE LOCATION (EDGE CENTER OF A CELL)
    !		 WILL ALSO BE RE-CALCULATED;
    !NOTES:
    !	  #. CREATED ON JAN 13 2009 (XIAOMING WANG,GNS)
    !	  #. UPDATED ON JAN 14 2009 (XIAOMING WANG,GNS)
    !----------------------------------------------------------------------
    USE LAYER_PARAMS
    TYPE (LAYER) :: LO
    TYPE (LAYER), DIMENSION(NUM_GRID) :: LA
    COMMON /CONS/ ELMAX, GRAV, PI, R_EARTH, GX, EPS, ZERO, ONE, NUM_GRID, &
            NUM_FLT, V_LIMIT, RAD_DEG, RAD_MIN

    !.....UPDATE FIRST-LEVEL GRIDS
    LO%H(:, :) = LO%H(:, :) - LO%DEFORM(:, :)
    IF (LO%INI_SWITCH.EQ.3 .OR. LO%INI_SWITCH.EQ.4) THEN
        LO%HT(:, :, 1) = LO%HT(:, :, 1) - LO%DEFORM(:, :)
        LO%HT(:, :, 2) = LO%HT(:, :, 2) - LO%DEFORM(:, :)
    ENDIF

    CALL PQ_DEPTH (LO)

    !.....UPDATE ALL SUB-LEVEL GRIDS
    DO I = 1, NUM_GRID
        IF (LA(I)%LAYSWITCH.EQ.0) THEN
            LA(I)%H(:, :) = LA(I)%H(:, :) - LA(I)%DEFORM(:, :)
            IF (LO%INI_SWITCH.EQ.3 .OR. LA(I)%INI_SWITCH.EQ.4) THEN
                LA(I)%HT(:, :, 1) = LA(I)%HT(:, :, 1) - LA(I)%DEFORM(:, :)
                LA(I)%HT(:, :, 2) = LA(I)%HT(:, :, 2) - LA(I)%DEFORM(:, :)
            ENDIF

            CALL PQ_DEPTH (LA(I))
        ENDIF
    ENDDO

    RETURN
END


!----------------------------------------------------------------------
SUBROUTINE ADJUST_BATHYMETRY (LO, LA)
    !......................................................................
    !DESCRIPTION:
    !	  #. MODIFY COMCOT BATHYMETRY DATA TO ACCOUNT IN TIDAL LEVEL AND
    !		 MINIMUM DEPTH SETUP;
    !	  #. WRITE COMCOT BATHYMETRY DATA INTO DATA FILES: LAYER##.DAT,
    !		 LAYER##_X.DAT, LAYER##_Y.DAT;
    !NOTES:
    !	  #. CREATED FEB 27 2009 (XIAOMING WANG, GNS)
    !----------------------------------------------------------------------
    USE LAYER_PARAMS
    TYPE (LAYER) :: LO
    TYPE (LAYER), DIMENSION(NUM_GRID) :: LA
    COMMON /CONS/ ELMAX, GRAV, PI, R_EARTH, GX, EPS, ZERO, ONE, NUM_GRID, &
            NUM_FLT, V_LIMIT, RAD_DEG, RAD_MIN

    WRITE (*, *) 'ADJUSTING BATHYMETRY AND SETUP SHORELINE...'
    IF (LO%LAYSWITCH .EQ. 0) THEN
        !CORRECTION CAUSED BY SEAFLOOR DEFORMATION ALREADY DONE
        !APPLY TIDAL LEVEL CORRECTION HERE
        IF (ABS(LO%TIDE_LEVEL).GT.GX) CALL TIDAL_CORRECTION (LO)
        !OUTPUT MODIFIED BATHYMETRY DATA
        !*		 IF (LO%FLUXSWITCH.EQ.9) CALL BATHY_WRITE (LO)
        !SETUP WALL BOUNDARY ALONG GIVEN DEPTH CONTOUR
        IF (ABS(LO%H_LIMIT).GT.GX) CALL DEPTH_LIMIT (LO)
        CALL PQ_DEPTH (LO)
    END IF
    DO I = 1, NUM_GRID
        IF (LA(I)%LAYSWITCH .EQ. 0) THEN
            !CORRECTION CAUSED BY SEAFLOOR DEFORMATION ALREADY DONE
            !APPLY TIDAL LEVEL CORRECTION HERE
            IF (ABS(LA(I)%TIDE_LEVEL).GT.GX) THEN
                CALL TIDAL_CORRECTION (LA(I))
            ENDIF
            !OUTPUT MODIFIED BATHYMETRY DATA
            !*			IF (LA(I)%FLUXSWITCH.EQ.9) CALL BATHY_WRITE (LA(I))
            !SETUP WALL BOUNDARY ALONG GIVEN DEPTH CONTOUR
            IF (ABS(LA(I)%H_LIMIT).GT.GX) CALL DEPTH_LIMIT (LA(I))
            CALL PQ_DEPTH (LA(I))
        END IF
    END DO

    RETURN
END

!----------------------------------------------------------------------
SUBROUTINE PQ_DEPTH (LO)
    !DESCRIPTION:
    !	  #. CALCULATE STILL WATER DEPTH AT DISCHARGE LOCATION P AND Q
    !NOTES:
    !	  #. CREATED ON NOV 25 2008 (XIAOMING WANG, GNS)
    !----------------------------------------------------------------------
    USE LAYER_PARAMS
    TYPE (LAYER) :: LO
    COMMON /CONS/ ELMAX, GRAV, PI, R_EARTH, GX, EPS, ZERO, ONE, NUM_GRID, &
            NUM_FLT, V_LIMIT, RAD_DEG, RAD_MIN

    DO I = 1, LO%NX
        IP1 = I + 1
        IF (IP1 .GE. LO%NX) IP1 = LO%NX
        DO J = 1, LO%NY
            JP1 = J + 1
            IF (JP1 .GE. LO%NY) JP1 = LO%NY
            IF (LO%H(I, J) .GT. GX) THEN
                LO%HP(I, J) = 0.5 * (LO%H(I, J) + LO%H(IP1, J))
                LO%HQ(I, J) = 0.5 * (LO%H(I, J) + LO%H(I, JP1))
            ENDIF
        END DO
    END DO

    RETURN
END


!----------------------------------------------------------------------
SUBROUTINE READ_FRIC_COEF1 (LO)
    !......................................................................
    !DESCRIPTION:
    !	  #. READ MANNING'S ROUGHNESS COEFFICIENTS
    !	  #. ONLY USED WHEN VARIABLE FRICTION COEFS ARE IMPLEMENTED.
    !	  #. ROUGHNESS COEFICIENTS SHOULD BE WRITTEN ROW BY ROW FROM LEFT
    !		 TO RIGHT (OR FROM WEST TO EAST);
    !NOTES:
    !	  #. CREATED ON ???? (XIAOMING WANG, CORNELL UNIVERSITY)
    !	  #. SUBROUTINE WAS REWRITTEN ON DEC 18 2008
    !	  #. FILE FORMAT CHANGES TO XYZ FORMAT
    !	  #. SIGNIFICATLY MODIFIED ON DEC 18 2008 (XIAOMING WANG, GNS)
    !----------------------------------------------------------------------
    USE LAYER_PARAMS
    TYPE (LAYER) :: LO
    REAL H_MAX, SOUTH_LAT, DX, CR

    REAL, ALLOCATABLE :: HTMP(:, :), H(:, :)
    REAL, ALLOCATABLE :: XCOL(:), YCOL(:), ZCOL(:)
    REAL, ALLOCATABLE :: X(:), Y(:), YTMP(:)
    INTEGER      STAT, IS, JS, I, J
    !      INTEGER	   LENGTH, RC, POS !, FLAG
    INTEGER      COUNT
    INTEGER :: RSTAT
    CHARACTER(LEN = 40) FNAME, FNAME1
    RSTAT = 0
    !----------------------------------------
    !  READING PARAMETERS FOR FRICTION COEF.
    !----------------------------------------
    WRITE (FNAME, 1) LO%ID
    1    FORMAT('fric_coef_layer', I2.2, '.dat')
    WRITE (*, *) '    READING ROUGHNESS COEF DATA FOR LAYER', LO%ID
    OPEN (UNIT = 23, FILE = FNAME, STATUS = 'OLD', IOSTAT = ISTAT, FORM = 'FORMATTED')
    IF (ISTAT /=0) THEN
        PRINT *, "ERROR:: CAN'T OPEN ROUGHNESS COEF. FILE; EXITING."
        STOP
    END IF

    !.....DETERMINE THE LENGTH OF ROUGHNESS DATA FILE
    COUNT = -1
    TEMP = 0.0
    DO WHILE (RSTAT == 0)
        COUNT = COUNT + 1
        READ (23, *, IOSTAT = RSTAT) TEMP1, TEMP2, TEMP3
    ENDDO
    NXY = COUNT
    ALLOCATE(XCOL(NXY))
    ALLOCATE(YCOL(NXY))
    ALLOCATE(ZCOL(NXY))
    XCOL = 0.0
    YCOL = 0.0
    ZCOL = 0.0

    !*!.....READING MANNING ROUGHNESS DATA
    REWIND(23)
    DO I = 1, COUNT
        READ (23, *) XCOL(I), YCOL(I), ZCOL(I)
        IF (ZCOL(I)/=ZCOL(I)) ZCOL(I) = 0.0
        IF (ABS(ZCOL(I)).GE.HUGE(ZCOL(I))) ZCOL(I) = 0.0
    END DO
    CLOSE (23)

    !.....DETERMINE GRID DIMENSION: NX,NY
    TEMP = XCOL(1)
    TEMP1 = XCOL(2)
    K = 1
    DO WHILE (TEMP1.GT.TEMP)
        K = K + 1
        TEMP1 = XCOL(K)
    ENDDO
    NX = K - 1
    NY = NINT(DBLE(NXY / NX))
    !	  WRITE (*,*) '       GRID DIMENSION: ', NX,NY
    ALLOCATE(X(NX))
    ALLOCATE(Y(NY))
    ALLOCATE(YTMP(NY))
    ALLOCATE(HTMP(NX, NY))
    ALLOCATE(H(NX, NY))
    X = 0.0
    Y = 0.0
    YTMP = 0.0
    HTMP = 0.0
    H = 0.0

    !.....OBTAINED X,Y COORDINATES
    X(1:NX) = XCOL(1:NX)
    DO J = 1, NY
        K = (J - 1) * NX + 1
        YTMP(J) = YCOL(K)
    END DO
    !GENERATE GRID DATA
    DO J = 1, NY
        KS = (J - 1) * NX + 1
        KE = (J - 1) * NX + NX
        HTMP(1:NX, J) = ZCOL(KS:KE)
    END DO

    !!....DETERMINE IF THE DATA NEED FLIP:
    !     I.E., Y COORDINATE IS FROM NORTH TO SOUTH OR FROM SOUTH TO NORTH
    !     IFLIP = 0: FLIP; 1: NO FLIP OPERATION
    IFLIP = 0
    IF (YTMP(NY).LT.YTMP(NY - 1)) IFLIP = 1

    IF (IFLIP .EQ. 1) THEN
        ! FLIP Y COORDINATES
        DO J = 1, NY
            K = NY - J + 1
            Y(K) = YTMP(J)
        END DO
        ! FLIP BATHYMETRY MATRIX
        DO I = 1, NX
            DO J = 1, NY
                K = NY - J + 1
                H(I, K) = HTMP(I, J)
            END DO
        END DO
    ELSE
        Y = YTMP
        H = HTMP
    END IF
    !*      WRITE (*,*) H(1,1),H(NX,NY),ZCOL(1),ZCOL(NXY)
    CALL GRID_INTERP (LO%FRIC_VCOEF, LO%X, LO%Y, LO%NX, LO%NY, H, X, Y, NX, NY)

    !.....OUTPUT THE FRICTION COEF INTO A DATA FILE
    IF (LO%LEVEL.LE.1) THEN
        IS = 1
        JS = 1
        IE = LO%NX
        JE = LO%NY
    ELSE
        IS = 2
        JS = 2
        IE = LO%NX
        JE = LO%NY
    ENDIF
    WRITE (FNAME1, 2) LO%ID
    2    FORMAT('friction_layer', I2.2, '.dat')
    OPEN (23, FILE = FNAME1, STATUS = 'UNKNOWN')
    DO J = JS, JE
        WRITE (23, '(15F9.4)') (LO%FRIC_VCOEF(I, J), I = IS, IE)
    ENDDO
    CLOSE (23)

    !.....FREE ALOOCATED VARIABLES
    DEALLOCATE(HTMP, H, STAT = ISTAT)
    DEALLOCATE(XCOL, YCOL, ZCOL, STAT = ISTAT)
    DEALLOCATE(X, Y, YTMP, STAT = ISTAT)

    RETURN
END

!----------------------------------------------------------------------
SUBROUTINE READ_FRIC_COEF (LO)
    !......................................................................
    !DESCRIPTION:
    !	  #. READ MANNING'S ROUGHNESS COEFFICIENTS
    !	  #. ONLY USED WHEN VARIABLE FRICTION COEFS ARE IMPLEMENTED.
    !	  #. ROUGHNESS COEFICIENTS SHOULD BE WRITTEN ROW BY ROW FROM LEFT
    !		 TO RIGHT (OR FROM WEST TO EAST);
    !NOTES:
    !	  #. CREATED ON ???? (XIAOMING WANG, CORNELL UNIVERSITY)
    !	  #. SUBROUTINE WAS REWRITTEN ON DEC 18 2008
    !	  #. FILE FORMAT CHANGES TO XYZ FORMAT
    !	  #. SIGNIFICATLY MODIFIED ON DEC 18 2008 (XIAOMING WANG, GNS)
    !	  #. UPDATED ON APR10 2009 (XIAOMING WANG, GNS)
    !		 - DATA ALLOWS TO BE WRITTEN EITHER COLUMN BY COLUMN
    !		   OR ROW BY ROW; BUT MUST BE FROM LEFT TO RIGHT;
    !----------------------------------------------------------------------
    USE LAYER_PARAMS
    TYPE (LAYER) :: LO
    REAL, ALLOCATABLE :: HTMP(:, :), H(:, :)
    REAL, ALLOCATABLE :: XCOL(:), YCOL(:), ZCOL(:)
    REAL, ALLOCATABLE :: X(:), Y(:), XTMP(:), YTMP(:)
    INTEGER      STAT, IS, JS, I, J, NXY
    INTEGER      COUNT
    INTEGER :: RSTAT
    CHARACTER(LEN = 40) FNAME, FNAME1
    COMMON /CONS/ ELMAX, GRAV, PI, R_EARTH, GX, EPS, ZERO, ONE, NUM_GRID, &
            NUM_FLT, V_LIMIT, RAD_DEG, RAD_MIN
    RSTAT = 0
    !----------------------------------------
    !  READING PARAMETERS FOR FRICTION COEF.
    !----------------------------------------
    WRITE (FNAME, 1) LO%ID
    1    FORMAT('fric_coef_layer', I2.2, '.dat')
    WRITE (*, *) '    READING ROUGHNESS COEF DATA FOR LAYER', LO%ID
    OPEN (UNIT = 23, FILE = FNAME, STATUS = 'OLD', IOSTAT = ISTAT, FORM = 'FORMATTED')
    IF (ISTAT /=0) THEN
        PRINT *, "ERROR:: CAN'T OPEN ROUGHNESS COEF. FILE; EXITING."
        STOP
    END IF

    !.....DETERMINE THE LENGTH OF ROUGHNESS DATA FILE
    COUNT = -1
    DO WHILE (RSTAT == 0)
        COUNT = COUNT + 1
        READ (23, *, IOSTAT = RSTAT) TEMP1, TEMP2, TEMP3
    ENDDO
    NXY = COUNT
    ALLOCATE(XCOL(NXY))
    ALLOCATE(YCOL(NXY))
    ALLOCATE(ZCOL(NXY))
    XCOL = 0.0
    YCOL = 0.0
    ZCOL = 0.0

    !*!.....READING ROUGHNESS DATA
    REWIND(23)
    DO I = 1, COUNT
        READ (23, *) XCOL(I), YCOL(I), ZCOL(I)
        IF (ZCOL(I)/=ZCOL(I)) ZCOL(I) = 9999.0
        IF (ABS(ZCOL(I)).GE.HUGE(ZCOL(I))) ZCOL(I) = 9999.0
    END DO
    CLOSE (23)

    !<<<  CHECK IF THE DATA IS WRITTEN ROW BY ROW
    !.....DETERMINE GRID DIMENSION: NX,NY
    TMPX = XCOL(1)
    TMPX1 = XCOL(2)
    TMPY = YCOL(1)
    TMPY1 = YCOL(2)
    IF (ABS(TMPX1 - TMPX).GT.EPS .AND. ABS(TMPY1 - TMPY).LT.EPS) THEN
        !*	  IF (TMPX1.NE.TMPX .AND. TMPY1.EQ.TMPY) THEN
        K = 1
        DO WHILE (TMPX1.GT.TMPX)
            K = K + 1
            TMPX1 = XCOL(K)
        ENDDO
        NX = K - 1
        NY = NINT(DBLE(NXY / NX))
        !	     WRITE (*,*) '       GRID DIMENSION OF GROUGHNESS DATA: ', NX,NY
        ALLOCATE(X(NX))
        ALLOCATE(Y(NY))
        ALLOCATE(YTMP(NY))
        ALLOCATE(HTMP(NX, NY))
        ALLOCATE(H(NX, NY))
        X = 0.0
        Y = 0.0
        YTMP = 0.0
        HTMP = 0.0
        H = 0.0

        !.....   OBTAINED X,Y COORDINATES
        X(1:NX) = XCOL(1:NX)
        DO J = 1, NY
            K = (J - 1) * NX + 1
            YTMP(J) = YCOL(K)
        END DO
        !GENERATE GRID DATA
        DO J = 1, NY
            KS = (J - 1) * NX + 1
            KE = (J - 1) * NX + NX
            HTMP(1:NX, J) = ZCOL(KS:KE)
        END DO
    ENDIF
    !>>>>>
    !<<<<<CHECK IF THE DATA IS WRITTEN COLUMN BY COLUMN
    TMPX = XCOL(1)
    TMPX1 = XCOL(2)
    TMPY = YCOL(1)
    TMPY1 = YCOL(2)
    !	  write (*,*) TMPX,TMPX1,TMPY,TMPY1,NXY
    IF (ABS(TMPX1 - TMPX).LT.EPS .AND. ABS(TMPY1 - TMPY).GT.EPS) THEN
        !*	  IF (TMPX1.EQ.TMPX .AND. TMPY1.NE.TMPY) THEN
        K = 1
        DO WHILE (TMPX1.LE.TMPX)
            K = K + 1
            TMPX1 = XCOL(K)
        ENDDO
        NY = K - 1
        !	     WRITE(*,*) NX
        NX = NINT(DBLE(NXY / NY))

        !*	     WRITE (*,*) '       GRID DIMENSION OF ROUGHNESS DATA: ', NX,NY
        ALLOCATE(X(NX))
        ALLOCATE(Y(NY))
        ALLOCATE(XTMP(NX))
        ALLOCATE(YTMP(NY))
        ALLOCATE(HTMP(NX, NY))
        ALLOCATE(H(NX, NY))
        HTMP = 0.0
        X = 0.0
        Y = 0.0
        YTMP = 0.0
        H = 0.0
        !........OBTAINED X,Y COORDINATES
        YTMP(1:NY) = YCOL(1:NY)
        DO I = 1, NX
            K = (I - 1) * NY + 1
            X(I) = XCOL(K)
        END DO
        !GENERATE GRID DATA
        DO I = 1, NX
            KS = (I - 1) * NY + 1
            KE = (I - 1) * NY + NY
            HTMP(I, 1:NY) = ZCOL(KS:KE)
        END DO
    ENDIF
    !>>>>>

    !!....DETERMINE IF THE DATA NEED FLIP
    !     CHECK IF Y COORDINATE IS FROM NORTH TO SOUTH OR FROM SOUTH TO NORTH
    !     IFLIP = 0: FLIP; 1: NO FLIP OPERATION
    IFLIP = 0
    IF (YTMP(NY).LT.YTMP(NY - 1)) IFLIP = 1

    IF (IFLIP .EQ. 1) THEN
        ! FLIP Y COORDINATES
        DO J = 1, NY
            K = NY - J + 1
            Y(K) = YTMP(J)
        END DO
        ! FLIP BATHYMETRY MATRIX
        DO I = 1, NX
            DO J = 1, NY
                K = NY - J + 1
                H(I, K) = HTMP(I, J)
            END DO
        END DO
    ELSE
        Y = YTMP
        H = HTMP
    END IF
    !*      WRITE (*,*) H(1,1),H(NX,NY),ZCOL(1),ZCOL(NXY)

    !.....MAP THE ROUGHNESS DATA ONTO THE NUMERICAL GRIDS VIA INTERPOLATION
    CALL GRID_INTERP (LO%FRIC_VCOEF, LO%X, LO%Y, LO%NX, LO%NY, H, X, Y, NX, NY)

    !.....OUTPUT THE FRICTION COEF INTO A DATA FILE
    IF (LO%LEVEL.LE.1) THEN
        IS = 1
        JS = 1
        IE = LO%NX
        JE = LO%NY
    ELSE
        IS = 2
        JS = 2
        IE = LO%NX
        JE = LO%NY
    ENDIF
    WRITE (FNAME1, 2) LO%ID
    2    FORMAT('friction_layer', I2.2, '.dat')
    OPEN (23, FILE = FNAME1, STATUS = 'UNKNOWN')
    DO J = JS, JE
        WRITE (23, '(15F9.4)') (LO%FRIC_VCOEF(I, J), I = IS, IE)
    ENDDO
    CLOSE (23)

    !.....FREE ALOOCATED VARIABLES
    DEALLOCATE(HTMP, H, STAT = ISTAT)
    DEALLOCATE(XCOL, YCOL, ZCOL, STAT = ISTAT)
    DEALLOCATE(X, Y, YTMP, STAT = ISTAT)

    RETURN
END
