! NOTE: Define DEBUG_ON through compilation macro for extra output.

MODULE Nemo_Adv_X_Run

    use Nemo_Adv_X_Helpers
    
    ! Set the working-precision to double precision.
    use, intrinsic :: iso_fortran_env, wp=>real64

    implicit none 
    
    public :: &
        run_mock

    ABSTRACT INTERFACE
        SUBROUTINE adv_x_func &
                (jpi, jpj, ncats, &
                 pdt, put, pcrh, psm, ps0, psx, psxx, psy , psyy, psxy, e1e2t, tmask)
            IMPORT :: wp

            INTEGER                   , INTENT(in   ) ::   jpi, jpj, ncats    ! Dimension of the workspace.
            REAL(wp)                  , INTENT(in   ) ::   pdt                ! the time step
            REAL(wp)                  , INTENT(in   ) ::   pcrh               ! call adv_x then adv_y (=1) or the opposite (=0)
            REAL(wp), DIMENSION(:,:)  , INTENT(in   ) ::   put                ! i-direction ice velocity at U-point [m/s]
            REAL(wp), DIMENSION(:,:,:), ALLOCATABLE, INTENT(inout) ::   psm                ! area
            REAL(wp), DIMENSION(:,:,:), ALLOCATABLE, INTENT(inout) ::   ps0                ! field to be advected
            REAL(wp), DIMENSION(:,:,:), ALLOCATABLE, INTENT(inout) ::   psx , psy          ! 1st moments 
            REAL(wp), DIMENSION(:,:,:), ALLOCATABLE, INTENT(inout) ::   psxx, psyy, psxy   ! 2nd moments
            REAL(wp), DIMENSION(:,:)  , ALLOCATABLE, INTENT(in   ) ::   e1e2t              ! associated metrics at t-point
            REAL(wp), DIMENSION(:,:,:), ALLOCATABLE, INTENT(in   ) ::   tmask              ! land/ocean mask at T-pts        
        END SUBROUTINE adv_x_func
    END INTERFACE
  
  CONTAINS
  
    SUBROUTINE run_mock(mock_func, func_name, time_seq, &
                        jpi, jpj, ncats, &
                        pdt, put, pcrh, psm, ps0, psx, psxx, psy , psyy, psxy, e1e2t, tmask, &
                        init_psm, init_ps0, init_psx, init_psxx, init_psy, init_psyy, init_psxy)
        ! Function specific variables.
        PROCEDURE(adv_x_func), POINTER, INTENT(in) :: mock_func
        CHARACTER(*), INTENT(in) :: func_name

        ! Stores sequential time.
        REAL(wp), INTENT(inout) :: time_seq

        ! Variables required for runs.
        INTEGER                   , INTENT(in) :: jpi, jpj, ncats   ! Dimension of the workspace.
        REAL(wp)                  , INTENT(in) :: pdt               ! the time step
        REAL(wp)                  , INTENT(in) :: pcrh              ! call adv_x then adv_y (=1) or the opposite (=0)
        REAL(wp), DIMENSION(:,:)  , INTENT(in) :: put               ! i-direction ice velocity at U-point [m/s]
        REAL(wp), DIMENSION(:,:)  , ALLOCATABLE, INTENT(in) :: e1e2t       ! associated metrics at t-point
        REAL(wp), DIMENSION(:,:,:), ALLOCATABLE, INTENT(in) :: tmask       ! land/ocean mask at T-pts    
        
        ! Variables to use during executions.
        REAL(wp), DIMENSION(:,:,:), ALLOCATABLE, INTENT(inout) :: psm                ! area
        REAL(wp), DIMENSION(:,:,:), ALLOCATABLE, INTENT(inout) :: ps0                ! field to be advected
        REAL(wp), DIMENSION(:,:,:), ALLOCATABLE, INTENT(inout) :: psx , psy          ! 1st moments 
        REAL(wp), DIMENSION(:,:,:), ALLOCATABLE, INTENT(inout) :: psxx, psyy, psxy   ! 2nd moments

        ! Variables to use as storage of initial values.
        REAL(wp), DIMENSION(:,:,:), ALLOCATABLE, INTENT(in) :: init_psm                            ! area
        REAL(wp), DIMENSION(:,:,:), ALLOCATABLE, INTENT(in) :: init_ps0                            ! field to be advected
        REAL(wp), DIMENSION(:,:,:), ALLOCATABLE, INTENT(in) :: init_psx, init_psy                  ! 1st moments 
        REAL(wp), DIMENSION(:,:,:), ALLOCATABLE, INTENT(in) :: init_psxx, init_psyy, init_psxy     ! 2nd moments
        
        ! Used for timing executions.
        REAL(wp) :: &
            time_start, &   ! Registers start time.
            time_exec       ! Registers end time - start time.

        ! Validation booleans per matrix.
        logical :: psm_val                         ! area
        LOGICAL :: ps0_val                         ! field to be advected
        LOGICAL :: psx_val, psy_val                ! 1st moments 
        LOGICAL :: psxx_val, psyy_val, psxy_val    ! 2nd moments

        ! Error values per matrix.
        REAL(wp) :: psm_err                        ! area
        REAL(wp) :: ps0_err                        ! field to be advected
        REAL(wp) :: psx_err, psy_err               ! 1st moments 
        REAL(wp) :: psxx_err, psyy_err, psxy_err   ! 2nd moments

        ! Global validation boolean and error real.
        LOGICAL :: validation
        REAL(wp) :: error

        ! Loop dummy variables.
        INTEGER :: i

        ! Performance test specific variables.
        INTEGER :: &
            NUM_DRY_RUNS, &     ! Number of dry-runs to perform.
            NUM_ITERS           ! Number of iterations.

        ! Set performance test specific variables.
        NUM_DRY_RUNS=10
        NUM_ITERS=1000

        ! Time the execution of multiple iterations.
        DO i=1,NUM_ITERS+NUM_DRY_RUNS
            IF (i == NUM_DRY_RUNS) THEN
                time_start = omp_get_wtime()
            END IF

            call mock_func &
                (jpi, jpj, ncats, &
                 pdt, put, pcrh, psm, ps0, psx, psxx, psy , psyy, psxy, e1e2t, tmask)
        END DO
        time_exec = omp_get_wtime() - time_start

        ! Overwrite sequential values, only if called by sequential.
        IF (func_name == "sequential") THEN
            time_seq = time_exec       
        END IF

        ! Print results.
        call print_perf_results_adv_x &
            (func_name, time_exec, time_seq / time_exec)

        ! Reset variables for next execution.
        call reset_adv_x &
            (init_psm, init_ps0, init_psx, init_psxx, init_psy, init_psyy, &
            init_psxy, psm, ps0, psx, psxx, psy, psyy, psxy)
    END SUBROUTINE run_mock
  
END MODULE Nemo_Adv_X_Run


program Nemo_Adv_X_Performance
    ! Local imports.
    use Nemo_Adv_X_Helpers
    use Nemo_Adv_X_Run

    ! External imports.
    use Nemo_Adv_X_Seq
    use Nemo_Adv_X_CPU
    use Nemo_Adv_X_Collapse
    use Nemo_Adv_X_Collapse_CPU
    use Nemo_Adv_X_Collapse_Custom
    use Nemo_Adv_X_Rc
    use Nemo_Adv_X_Rc_Collapsed
    use Nemo_Adv_X_Rc_Collapsed_Wrong
    use Nemo_Adv_X_Data_Beta
    use Nemo_Adv_X_Data_Cat

    REAL(wp) :: pdt             ! the time step
    REAL(wp) :: pcrh            ! call adv_x then adv_y (=1) or the opposite (=0)
    REAL(wp), DIMENSION(:,:), ALLOCATABLE :: put      ! i-direction ice velocity at U-point [m/s]
    REAL(wp), DIMENSION(:,:), ALLOCATABLE :: e1e2t    ! associated metrics at t-point
    REAL(wp), DIMENSION(:,:,:), ALLOCATABLE :: tmask  ! land/ocean mask at T-pts    

    ! Variables to use during executions.
    REAL(wp), DIMENSION(:,:,:), ALLOCATABLE :: psm                ! area
    REAL(wp), DIMENSION(:,:,:), ALLOCATABLE :: ps0                ! field to be advected
    REAL(wp), DIMENSION(:,:,:), ALLOCATABLE :: psx , psy          ! 1st moments
    REAL(wp), DIMENSION(:,:,:), ALLOCATABLE :: psxx, psyy, psxy   ! 2nd moments

    ! Variables to use as storage of sequential values.
    REAL(wp), DIMENSION(:,:,:), ALLOCATABLE :: seq_psm                         ! area
    REAL(wp), DIMENSION(:,:,:), ALLOCATABLE :: seq_ps0                         ! field to be advected
    REAL(wp), DIMENSION(:,:,:), ALLOCATABLE :: seq_psx, seq_psy                ! 1st moments
    REAL(wp), DIMENSION(:,:,:), ALLOCATABLE :: seq_psxx, seq_psyy, seq_psxy    ! 2nd moments

    ! Variables to use as storage of initial values.
    REAL(wp), DIMENSION(:,:,:), ALLOCATABLE :: init_psm                            ! area
    REAL(wp), DIMENSION(:,:,:), ALLOCATABLE :: init_ps0                            ! field to be advected
    REAL(wp), DIMENSION(:,:,:), ALLOCATABLE :: init_psx, init_psy                  ! 1st moments
    REAL(wp), DIMENSION(:,:,:), ALLOCATABLE :: init_psxx, init_psyy, init_psxy     ! 2nd moments

    ! Used for timing executions.
    REAL(wp) :: &
        time_start, &   ! Registers start time.
        time_seq        ! Stores sequential time.

    ! Function pointer used for executing the code.
    PROCEDURE(adv_x_func), POINTER :: mock_func

    ! Variables that indicate workspace dimensions.
    INTEGER :: JPI, JPJ, NCATS

#ifdef DEBUG_ON
    write (*,*) ""
    write (*,*) "IN: main_program."
#endif

    ! Initialize the "init_" variables required for running the mock code.
    call initialize_adv_x &
        (JPI, JPJ, NCATS &
         pdt, put, pcrh, init_psm , init_ps0, init_psx, init_psxx, init_psy, &
         init_psyy, init_psxy, e1e2t, tmask)

    ! Copy initialized variables for running the parallel experiments.
    psm = init_psm
    ps0 = init_ps0
    psx = init_psx
    psxx = init_psxx
    psy = init_psy
    psyy = init_psyy
    psxy = init_psxy

#ifdef DEBUG_ON
    write (*,*) "main_program: after initialization"
    write (*,*) "main_program: running sequential 1 thread.."
#endif
    !-----------------------------------------------------------------!
    !  Perf test sequential code, also stores timing for comparison.  !
    !-----------------------------------------------------------------!
    CALL OMP_SET_NUM_THREADS(1)
    mock_func => adv_x_mock_seq
    call run_mock(mock_func, "sequential", time_seq, &
        JPI, JPJ, NCATS, & 
        pdt, put, pcrh, psm, ps0, psx, psxx, psy , psyy, psxy, e1e2t, tmask, &
        init_psm, init_ps0, init_psx, init_psxx, init_psy, init_psyy, init_psxy)

#ifdef DEBUG_ON
    write (*,*) "main_program: running cpu 1 thread.."
#endif
    !-------------------------------------!
    !  Perf test cpu code with 1 thread.  !
    !-------------------------------------!
    mock_func => adv_x_mock_cpu
    call run_mock(mock_func, "cpu", time_seq, &
        JPI, JPJ, NCATS, & 
        pdt, put, pcrh, psm, ps0, psx, psxx, psy , psyy, psxy, e1e2t, tmask, &
        init_psm, init_ps0, init_psx, init_psxx, init_psy, init_psyy, init_psxy)        

#ifdef DEBUG_ON
    write (*,*) "main_program: running collapse_cpu 1 thread.."
#endif
    !----------------------------------------------!
    !  Perf test collapse_cpu code with 1 thread.  !
    !----------------------------------------------!
    mock_func => adv_x_mock_collapse_cpu
    call run_mock(mock_func, "collapse_cpu", time_seq, &
        JPI, JPJ, NCATS, & 
        pdt, put, pcrh, psm, ps0, psx, psxx, psy , psyy, psxy, e1e2t, tmask, &
        init_psm, init_ps0, init_psx, init_psxx, init_psy, init_psyy, init_psxy)        
    
#ifdef DEBUG_ON
    write (*,*) "main_program: running sequential 7 threads.."
#endif
    !---------------------------------------------!
    !  Perf test sequential code with 7 threads.  !
    !---------------------------------------------!
    CALL OMP_SET_NUM_THREADS(7)
    mock_func => adv_x_mock_seq
    call run_mock(mock_func, "seq_7threads", time_seq, &
        JPI, JPJ, NCATS, & 
        pdt, put, pcrh, psm, ps0, psx, psxx, psy , psyy, psxy, e1e2t, tmask, &
        init_psm, init_ps0, init_psx, init_psxx, init_psy, init_psyy, init_psxy)

#ifdef DEBUG_ON
    write (*,*) "main_program: running cpu 7 threads.."
#endif
    !-------------------------------------!
    !  Perf test cpu code with 7 thread.  !
    !-------------------------------------!
    mock_func => adv_x_mock_cpu
    call run_mock(mock_func, "cpu_7threads", time_seq, &
        JPI, JPJ, NCATS, & 
        pdt, put, pcrh, psm, ps0, psx, psxx, psy , psyy, psxy, e1e2t, tmask, &
        init_psm, init_ps0, init_psx, init_psxx, init_psy, init_psyy, init_psxy)              

#ifdef DEBUG_ON
    write (*,*) "main_program: running collapse_cpu 7 threads.."
#endif
    !----------------------------------------------!
    !  Perf test collapse_cpu code with 7 thread.  !
    !----------------------------------------------!
    mock_func => adv_x_mock_collapse_cpu
    call run_mock(mock_func, "collapse_cpu_7threads", time_seq, &
        JPI, JPJ, NCATS, & 
        pdt, put, pcrh, psm, ps0, psx, psxx, psy , psyy, psxy, e1e2t, tmask, &
        init_psm, init_ps0, init_psx, init_psxx, init_psy, init_psyy, init_psxy) 

#ifdef DEBUG_ON
    write (*,*) "main_program: running rc.."
#endif    
    !-----------------!
    !  Call rc code.  !
    !-----------------!
    mock_func => adv_x_mock_rc
    call run_mock(mock_func, "rc", time_seq, &
        JPI, JPJ, NCATS, & 
        pdt, put, pcrh, psm, ps0, psx, psxx, psy , psyy, psxy, e1e2t, tmask, &
        init_psm, init_ps0, init_psx, init_psxx, init_psy, init_psyy, init_psxy)    

#ifdef DEBUG_ON
    write (*,*) "main_program: running data_beta 7 threads.."
#endif
    !-----------------------------!
    !  Perf test data_beta code.  !
    !-----------------------------!
    mock_func => adv_x_mock_data_beta
    call run_mock(mock_func, "data_beta", time_seq, &
        JPI, JPJ, NCATS, & 
        pdt, put, pcrh, psm, ps0, psx, psxx, psy , psyy, psxy, e1e2t, tmask, &
        init_psm, init_ps0, init_psx, init_psxx, init_psy, init_psyy, init_psxy)        
    
#ifdef DEBUG_ON
    write (*,*) "main_program: running data_cat 7 threads.."
#endif
    !----------------------------!
    !  Perf test data_cat code.  !
    !----------------------------!
    mock_func => adv_x_mock_data_cat
    call run_mock(mock_func, "data_cat", time_seq, &
        JPI, JPJ, NCATS, & 
        pdt, put, pcrh, psm, ps0, psx, psxx, psy , psyy, psxy, e1e2t, tmask, &
        init_psm, init_ps0, init_psx, init_psxx, init_psy, init_psyy, init_psxy)        

#ifdef DEBUG_ON
    write (*,*) "main_program: running collapse_custom 7 threads.."
#endif
    !-----------------------------------!
    !  Perf test collapse_custom code.  !
    !-----------------------------------!
    mock_func => adv_x_mock_collapse_custom
    call run_mock(mock_func, "collapse_custom", time_seq, &
        JPI, JPJ, NCATS, & 
        pdt, put, pcrh, psm, ps0, psx, psxx, psy , psyy, psxy, e1e2t, tmask, &
        init_psm, init_ps0, init_psx, init_psxx, init_psy, init_psyy, init_psxy)    

#ifdef DEBUG_ON
    write (*,*) "main_program: running collapse 7 threads.."
#endif
    !----------------------------!
    !  Perf test collapse code.  !
    !----------------------------!
    mock_func => adv_x_mock_collapse
    call run_mock(mock_func, "collapse", time_seq, &
        JPI, JPJ, NCATS, & 
        pdt, put, pcrh, psm, ps0, psx, psxx, psy , psyy, psxy, e1e2t, tmask, &
        init_psm, init_ps0, init_psx, init_psxx, init_psy, init_psyy, init_psxy)    

#ifdef DEBUG_ON
    write (*,*) "OUT: main_program."
    write (*,*) ""
#endif

end program Nemo_Adv_X_Performance
