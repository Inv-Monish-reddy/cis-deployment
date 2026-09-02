cd "C:\CIS-Deployment\Simulation"
start "DragerSimulation" java ClientDragerVista120SDataSimulation
cd "C:\CIS-Deployment\Simulation"
@ECHO OFF
start SchillerNeumoventDevice.bat
cd "C:\CIS-Deployment\Simulationn"
@ECHO OFF
start BPLAcuraS1Device.bat

