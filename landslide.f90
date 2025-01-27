!----------------------------------------------------------------------
SUBROUTINE LAND_SLIDE (LO, LANDSLIDE_INFO, T)
    !DESCRIPTION:
    !	  #. CALCULATE TIME-VARIATION OF WATER DEPTH
    !		 ********* USE LANDSLIDE MODEL **************
    !NOTES:
    !	  #. CREATED ON ??? ??, (XIAOMING WANG, CORNELL UNIVERSITY)
    !	  #. UPDATED ON SEP17 2006 (XIAOMING WANG)
    !	  #. UPDATED ON NOV.27 2008 (XIAOMING WANG, GNS)
    !----------------------------------------------------------------------
    USE LAYER_PARAMS
    USE LANDSLIDE_PARAMS
    TYPE (LAYER) :: LO
    TYPE (LANDSLIDE) :: LANDSLIDE_INFO
    INTEGER :: NX, NY, NUM, IS, IE, JS, JE
    REAL  HS1(LANDSLIDE_INFO%NX, LANDSLIDE_INFO%NY)
    REAL  HS2(LANDSLIDE_INFO%NX, LANDSLIDE_INFO%NY)
    REAL  UPLIFT(LANDSLIDE_INFO%NX, LANDSLIDE_INFO%NY)
    REAL  TIME_SEQUENCE(LANDSLIDE_INFO%NT)
    REAL  T
    CHARACTER(LEN = 30) FNAME

    HS1 = 0.0
    HS2 = 0.0
    UPLIFT = 0.0
    TIME_SEQUENCE = 0.0

    IS = LANDSLIDE_INFO%CORNERS(1)
    IE = LANDSLIDE_INFO%CORNERS(2)
    JS = LANDSLIDE_INFO%CORNERS(3)
    JE = LANDSLIDE_INFO%CORNERS(4)

    IF (LANDSLIDE_INFO%OPTION .LE. 1) THEN
        TIME_SEQUENCE = LANDSLIDE_INFO%T

        !     DETERMINE THE POSITION OF CURRENT TIME IN THE TIME SEQUENCE
        K = 1
        DO I = 1, LANDSLIDE_INFO%NT - 1
            IF (T.GE.TIME_SEQUENCE(I) .AND.                            &
                    T.LT.TIME_SEQUENCE(I + 1)) THEN
                K = I
            ENDIF
        ENDDO

        IF (TIME_SEQUENCE(LANDSLIDE_INFO%NT) - T .LE. 0.000001)        &
                K = LANDSLIDE_INFO%NT - 1

        DT = TIME_SEQUENCE(K + 1) - TIME_SEQUENCE(K)
        HS1(:, :) = LANDSLIDE_INFO%SNAPSHOT(:, :, K)
        HS2(:, :) = LANDSLIDE_INFO%SNAPSHOT(:, :, K + 1)
        !.....DEFORMATION AT T IS INTERPOLATED FROM HS1 AND HS2
        DO I = 1, LANDSLIDE_INFO%NX
            DO J = 1, LANDSLIDE_INFO%NY
                UPLIFT(I, J) = HS1(I, J) + (HS2(I, J) - HS1(I, J)) / DT        &
                        * (T - TIME_SEQUENCE(K))
            ENDDO
        ENDDO

        LO%HT(IS:IE, JS:JE, 2) = LO%H(IS:IE, JS:JE) - UPLIFT(:, :)
        !         LO%H2(IS:IE,JS:JE) = UPLIFT(:,:)
    ELSEIF (LANDSLIDE_INFO%OPTION .EQ. 2) THEN
        CALL LANDSLIDE_FUNCTION (LO, LANDSLIDE_INFO, T)
        LO%HT(IS:IE, JS:JE, 2) = LO%H(IS:IE, JS:JE)                    &
                - LANDSLIDE_INFO%SNAPSHOT(:, :, 3)
    ENDIF

    RETURN
END


!----------------------------------------------------------------------
SUBROUTINE READ_LANDSLIDE (LO, LANDSLIDE_INFO)
    !.....READ SNAPSHOTS OF LANDSLIDE DATA
    !     ONLY USED WHEN WAVE TYPE OPTION IS 2.
    !.....LAST REVISE: NOV.24 2008 (XIAOMING WANG)
    !----------------------------------------------------------------------
    USE LAYER_PARAMS
    USE LANDSLIDE_PARAMS
    TYPE (LANDSLIDE) :: LANDSLIDE_INFO
    TYPE (LAYER) :: LO
    REAL, ALLOCATABLE :: SNAPSHOT(:, :, :), X(:), Y(:), T(:)
    INTEGER COUNT, NX, NY, NT
    INTEGER :: RSTAT = 0
    REAL LATIN, LONIN, XS, YS, XE, YE, XT, YT, X0, Y0
    CHARACTER(LEN = 80) FNAME

    DO K = 1, LO%NX - 1
        IF (LANDSLIDE_INFO%X_START.GT.LO%X(K) .AND.                &
                LANDSLIDE_INFO%X_START.LE.LO%X(K + 1)) THEN
            LANDSLIDE_INFO%CORNERS(1) = K + 1
        ENDIF
        IF (LANDSLIDE_INFO%X_END.GE.LO%X(K) .AND.                    &
                LANDSLIDE_INFO%X_END.LT.LO%X(K + 1)) THEN
            LANDSLIDE_INFO%CORNERS(2) = K
        ENDIF
    ENDDO

    DO K = 1, LO%NY - 1
        IF (LANDSLIDE_INFO%Y_START.GT.LO%Y(K) .AND.                &
                LANDSLIDE_INFO%Y_START.LE.LO%Y(K + 1)) THEN
            LANDSLIDE_INFO%CORNERS(3) = K + 1
        ENDIF
        IF (LANDSLIDE_INFO%Y_END.GE.LO%Y(K) .AND.                    &
                LANDSLIDE_INFO%Y_END.LT.LO%Y(K + 1)) THEN
            LANDSLIDE_INFO%CORNERS(4) = K
        ENDIF
    ENDDO
    !.....CALCULATE DIMENSION OF LANDSLIDE REGION
    LANDSLIDE_INFO%NX = LANDSLIDE_INFO%CORNERS(2)                    &
            - LANDSLIDE_INFO%CORNERS(1) + 1
    LANDSLIDE_INFO%NY = LANDSLIDE_INFO%CORNERS(4)                    &
            - LANDSLIDE_INFO%CORNERS(3) + 1

    !USE THE OLD COMCOT DATA FORMAT: NOT SUGGESTED
    IF (LANDSLIDE_INFO%OPTION .EQ. 0) THEN

        OPEN(UNIT = 20, FILE = 'bottom_motion_time.dat', STATUS = 'OLD', &
                IOSTAT = ISTAT)
        IF (ISTAT /=0) THEN
            PRINT *, "ERROR:: CAN'T OPEN BOTTOM_MOTION_TIME.DAT; EXITING."
            STOP
        ENDIF
        COUNT = -1
        DO WHILE (RSTAT == 0)
            COUNT = COUNT + 1
            READ (20, *, IOSTAT = RSTAT) TEMP
        END DO
        LANDSLIDE_INFO%NT = COUNT
        !	     CLOSE(20)
        ALLOCATE(LANDSLIDE_INFO%T(COUNT))
        ALLOCATE(LANDSLIDE_INFO%SNAPSHOT(LANDSLIDE_INFO%NX, &
                LANDSLIDE_INFO%NY, COUNT))
        ALLOCATE(SNAPSHOT(LANDSLIDE_INFO%NX, LANDSLIDE_INFO%NY, &
                COUNT))
        LANDSLIDE_INFO%T = 0.0
        LANDSLIDE_INFO%SNAPSHOT = 0.0
        SNAPSHOT = 0.0
        !		 !OBTAIN TIME SEQUENCE
        REWIND(20)
        !         OPEN(UNIT=20,FILE='bottom_motion_time.dat',STATUS='OLD',	&
        !						IOSTAT=ISTAT)
        DO I = 1, LANDSLIDE_INFO%NT
            READ (20, *) LANDSLIDE_INFO%T(I)
        ENDDO
        CLOSE(20)
        LANDSLIDE_INFO%DURATION = &
                LANDSLIDE_INFO%T(LANDSLIDE_INFO%NT)    &
                        - LANDSLIDE_INFO%T(1)

        !.....   READ SEAFLOOR DEFORMATION DATA FROM SEQUENTIAL SNAPSHOTS
        DO K = 1, COUNT
            WRITE (FNAME, 1) K
            1          FORMAT('bottom_motion_', I6.6, '.dat')
            OPEN (25, FILE = FNAME, STATUS = 'OLD', IOSTAT = ISTAT)
            IF (ISTAT /=0) THEN
                PRINT *, "ERROR:: CAN'T OPEN LANDSLIDE FILE; EXITING."
                STOP
            ENDIF
            DO J = 1, LANDSLIDE_INFO%NY
                DO I = 1, LANDSLIDE_INFO%NX
                    READ (25, *) SNAPSHOT(I, J, K)
                ENDDO
            ENDDO
            !*	        WRITE (*,*) FNAME
            CLOSE (25)
            LANDSLIDE_INFO%SNAPSHOT = SNAPSHOT
        ENDDO
    ENDIF
    !LANDSLIDE SNAPSHOTS ADOPT XYT DATA FORMAT
    IF (LANDSLIDE_INFO%OPTION .EQ. 1) THEN
        OPEN(UNIT = 20, FILE = LANDSLIDE_INFO%FILENAME, STATUS = 'OLD', &
                IOSTAT = ISTAT)
        IF (ISTAT /=0) THEN
            PRINT *, "ERROR:: CAN'T OPEN LANDSLIDE FILE; EXITING."
            STOP
        ENDIF
        READ (20, *) NX, NY, NT

        ALLOCATE(X(NX))
        ALLOCATE(Y(NY))
        ALLOCATE(T(NT))
        ALLOCATE(SNAPSHOT(NX, NY, NT))
        X = 0.0
        Y = 0.0
        T = 0.0
        SNAPSHOT = 0.0

        DO I = 1, NX
            READ(20, *) X(I)
        ENDDO
        DO J = 1, NY
            READ(20, *) Y(J)
        ENDDO
        DO K = 1, NT
            READ(20, *) T(K)
        ENDDO
        DO K = 1, NT
            DO J = 1, NY
                DO I = 1, NX
                    READ(20, *) SNAPSHOT(I, J, K)
                ENDDO
            ENDDO
        ENDDO
        CLOSE(20)

        ALLOCATE(LANDSLIDE_INFO%T(NT))
        LANDSLIDE_INFO%T = 0.0

        LANDSLIDE_INFO%NT = NT
        LANDSLIDE_INFO%T = T
        LANDSLIDE_INFO%DURATION = T(NT) - T(1)

        IS = LANDSLIDE_INFO%CORNERS(1)
        IE = LANDSLIDE_INFO%CORNERS(2)
        JS = LANDSLIDE_INFO%CORNERS(3)
        JE = LANDSLIDE_INFO%CORNERS(4)

        ALLOCATE(LANDSLIDE_INFO%SNAPSHOT(LANDSLIDE_INFO%NX, &
                LANDSLIDE_INFO%NY, NT))
        LANDSLIDE_INFO%SNAPSHOT = 0.0

        DO K = 1, NT
            CALL GRID_INTERP (LANDSLIDE_INFO%SNAPSHOT(:, :, K), &
                    LO%X(IS:IE), LO%Y(JS:JE), &
                    LANDSLIDE_INFO%NX, LANDSLIDE_INFO%NY, &
                    SNAPSHOT(:, :, K), X, Y, NX, NY)
            !*			LANDSLIDE_INFO%SNAPSHOT(:,:,K) =						&
            !*				- LANDSLIDE_INFO%SNAPSHOT(:,:,K) + LO%H(IS:IE,JS:JE)
        ENDDO
    ENDIF
    !	  WRITE(*,*) NX,NT,NT
    !	  WRITE(*,*) X(1),Y(1),T(1),SNAPSHOT(1,1,NT),SNAPSHOT(1,NY,NT),	&
    !							SNAPSHOT(NX,1,NT),SNAPSHOT(NX,NY,NT)
    !	  WRITE(*,*) LANDSLIDE_INFO%SNAPSHOT(1,LANDSLIDE_INFO%NY,NT)

    !USE PROFILE FUNCTION TO GENEATE SNAPSHOTS OF LANDSLIDE PROFILE
    !NOTE: LANDSLIDE_INFO%SNAPSHOT IS USED TO STORE COORDINATES
    IF (LANDSLIDE_INFO%OPTION .EQ. 2) THEN
        CALL GET_LANDSLIDE_PARAMETERS (LO, LANDSLIDE_INFO)
        NX = LANDSLIDE_INFO%NX
        NY = LANDSLIDE_INFO%NY
        NT = LANDSLIDE_INFO%NT
        XS = LANDSLIDE_INFO%XS
        YS = LANDSLIDE_INFO%YS
        XE = LANDSLIDE_INFO%XE
        YE = LANDSLIDE_INFO%YE

        ALLOCATE(SNAPSHOT(NX, NY, 2))
        ALLOCATE(LANDSLIDE_INFO%SNAPSHOT(NX, NY, 3))
        SNAPSHOT = 0.0
        LANDSLIDE_INFO%SNAPSHOT = 0.0

        !COORDINATE CONVERSION (IF SPHERICAL COORD. IS ADOPTED)AND ROTATION
        IS = LANDSLIDE_INFO%CORNERS(1)
        IE = LANDSLIDE_INFO%CORNERS(2)
        JS = LANDSLIDE_INFO%CORNERS(3)
        JE = LANDSLIDE_INFO%CORNERS(4)
        IF (LO%LAYCORD .EQ. 1) THEN
            X0 = LANDSLIDE_INFO%XS
            Y0 = LANDSLIDE_INFO%YS
            !ROTATE COORDINATES TO ALIGN WITH SLIDING PATH
            LANDSLIDE_INFO%DISTANCE = SQRT((XE - XS)**2 + (YE - YS)**2)
            SN = (YE - YS) / LANDSLIDE_INFO%DISTANCE
            CS = (XE - XS) / LANDSLIDE_INFO%DISTANCE
            DO I = 1, NX
                DO J = 1, NY
                    XT = LO%X(I + IS - 1) - X0
                    YT = LO%Y(J + JS - 1) - Y0
                    XR = XT * CS + YT * SN
                    YR = -XT * SN + YT * CS
                    LANDSLIDE_INFO%SNAPSHOT(I, J, 1) = XR
                    LANDSLIDE_INFO%SNAPSHOT(I, J, 2) = YR
                    LANDSLIDE_INFO%SNAPSHOT(I, J, 3) = 0.0
                ENDDO
            ENDDO
            !*			CALL LANDSLIDE_FUNCTION (LO,LANDSLIDE_INFO,0.0)
        ELSEIF (LO%LAYCORD .EQ. 0) THEN
            X0 = LANDSLIDE_INFO%XS
            Y0 = LANDSLIDE_INFO%YS
            LONIN = LANDSLIDE_INFO%XS
            LATIN = LANDSLIDE_INFO%YS
            !CONVERTING SPHERICAL COORDINATES TO CARTESIAN COORDINATES
            CALL STEREO_PROJECTION (XS, YS, LONIN, LATIN, X0, Y0)
            LONIN = LANDSLIDE_INFO%XE
            LATIN = LANDSLIDE_INFO%YE
            !CONVERTING SPHERICAL COORDINATES TO CARTESIAN COORDINATES
            CALL STEREO_PROJECTION (XE, YE, LONIN, LATIN, X0, Y0)
            LANDSLIDE_INFO%DISTANCE = SQRT((XE - XS)**2 + (YE - YS)**2)
            SN = (YE - YS) / LANDSLIDE_INFO%DISTANCE
            CS = (XE - XS) / LANDSLIDE_INFO%DISTANCE
            DO I = 1, NX
                DO J = 1, NY
                    LONIN = LO%X(I + IS - 1)
                    LATIN = LO%Y(J + JS - 1)
                    !CONVERTING SPHERICAL COORDINATES TO CARTESIAN COORDINATES
                    CALL STEREO_PROJECTION (XT, YT, LONIN, LATIN, X0, Y0)
                    !ROTATING COORDINATES TO ALIGN WITH SLIDING PATH
                    XR = XT * CS + YT * SN
                    YR = -XT * SN + YT * CS
                    LANDSLIDE_INFO%SNAPSHOT(I, J, 1) = XR
                    LANDSLIDE_INFO%SNAPSHOT(I, J, 2) = YR
                    LANDSLIDE_INFO%SNAPSHOT(I, J, 3) = 0.0
                ENDDO
            ENDDO
            !*			CALL LANDSLIDE_FUNCTION (LO,LANDSLIDE_INFO,T)
        ENDIF
    ENDIF

    DEALLOCATE(SNAPSHOT, X, Y, T, STAT = ISTAT)

    RETURN
END

!----------------------------------------------------------------------
SUBROUTINE LANDSLIDE_FUNCTION (LO, LS, TIME)
    !DESCRIPTION:
    !	  #. GENERATE LANDSLIDE FROM FUNCTION;
    !	  #. WATER DEPTH VARIATION IS DETERMINED FROM  WATTS ET AL (2003);
    !REFERENCE:
    !	  #. WATTS ET AL (2003), NATURAL HAZARDS AND EARTH SYSTEM SCIENCES,
    !		 (2003) 3:391-402
    !NOTES:
    !	  #. CREATED ON FEB06 2009 (XIAOMING WANG, GNS)
    !	  #. UPDATED ON ??
    !----------------------------------------------------------------------
    USE LAYER_PARAMS
    USE LANDSLIDE_PARAMS
    TYPE (LAYER) :: LO
    TYPE (LANDSLIDE) :: LS
    INTEGER :: NX, NY, IS, IE, JS, JE
    REAL  TIME, T, T0, S0, A0, UT, B, SN
    REAL X, Y, Z, C, ZE, ZD
    REAL D, D_LIMIT
    COMMON /CONS/ ELMAX, GRAV, PI, R_EARTH, GX, EPS, ZERO, ONE, NUM_GRID, &
            NUM_FLT, V_LIMIT, RAD_DEG, RAD_MIN

    UPLIFT = 0.0

    THETA = LS%SLOPE * RAD_DEG
    SN = SIN(THETA)
    A = LS%A
    B = LS%B
    C = LS%THICKNESS

    T = TIME - LS%T(1)
    IF (T .LE. 0.0) T = 0.0
    A0 = 0.30 * GRAV * SN
    UT = 1.16 * SQRT(A * GRAV * SN)
    S0 = UT**2 / A0
    T0 = UT / A0
    S = S0 * LOG(COSH(T / T0))

    D = S * COS(THETA)
    D_LIMIT = LS%DISTANCE

    IF (T.GE.LS%T(1) .AND. T.LE.LS%T(LS%NT)                        &
            .AND. D.LE.D_LIMIT) THEN
        DO I = 1, LS%NX
            DO J = 1, LS%NY
                X = LS%SNAPSHOT(I, J, 1)
                Y = LS%SNAPSHOT(I, J, 2)
                CALL SLIDEPROFILE_ELLIPSOID (ZE, X - S, Y, A, B, C)
                CALL SLIDEPROFILE_ELLIPSOID (ZD, X, Y, A, B, C)
                LS%SNAPSHOT(I, J, 3) = ZE - ZD
            ENDDO
        ENDDO
    ENDIF

    RETURN
END

!----------------------------------------------------------------------
SUBROUTINE SLIDEPROFILE_ELLIPSOID (Z, X, Y, A, B, C)
    !DESCRIPTION:
    !	  #. SLIDE PROFILE: ELLIPOID;
    !NOTES:
    !	  #. CREATED ON FEB13 2009 (XIAOMING WANG, GNS)
    !	  #. UPDATED ON ??
    !----------------------------------------------------------------------
    REAL X, Y, Z, A, B, C

    TMP = 1.0 - (X / A)**2 - (Y / B)**2
    IF (TMP .GE. 0.0) THEN
        Z = C * SQRT(TMP)
    ELSE
        Z = 0.0
    ENDIF

    RETURN
END
