# c-style unhygenic macros for constructing test circuits

macro circuit1()

    esc(quote
        circ = Circuit()
        r1 = Resistor(5e+3)
        r2 = Resistor(10e+3)
        v_DC = DCVoltageSource(5.)
        connect!(circ, v_DC.pHigh, r1.p1)
        connect!(circ, r1.p2, r2.p1)
        connect!(circ, r2.p2, v_DC.pLow)
        connect!(circ, circ.gnd, v_DC.pLow)
    end)
end

macro circuit2()

    esc(quote
        circ = Circuit()
        r1 = Resistor(5e+3)
        r2 = Resistor(10e+3)
        r3 = Resistor(7e+3)
        v_DC_1 = DCVoltageSource(5.)
        v_DC_2 = DCVoltageSource(10.)
        connect!(circ, v_DC_1.pHigh, r1.p1, "Node 1")
        connect!(circ, r1.p2, r2.p1, "Node 2")
        connect!(circ, r2.p2, v_DC_1.pLow)
        connect!(circ, circ.gnd, r3.p1)
        connect!(circ, r3.p2, v_DC_2.pLow, "Node 3")
        connect!(circ, r1.p2, v_DC_2.pHigh)
        connect!(circ, circ.gnd, v_DC_1.pLow)
    end)
end

# same as the above circuit, but replace v_DC_1 
# with a current source instead
macro circuit3()
    
    esc(quote
        circ = Circuit()
        r1 = Resistor(5e+3)
        r2 = Resistor(10e+3)
        r3 = Resistor(7e+3)
        i_DC_1 = DCCurrentSource(10e-3)
        v_DC_2 = DCVoltageSource(10.)
        connect!(circ, i_DC_1.pOut, r1.p1, "Node 1")
        connect!(circ, r1.p2, r2.p1, "Node 2")
        connect!(circ, r2.p2, i_DC_1.pIn)
        connect!(circ, circ.gnd, r3.p1)
        connect!(circ, r3.p2, v_DC_2.pLow, "Node 3")
        connect!(circ, r1.p2, v_DC_2.pHigh)
        connect!(circ, circ.gnd, i_DC_1.pIn)
    end)
end

# a simple current source circuit
# 40mA current source and a 1k resistor (ground on the source in)
macro circuit4()
    
    esc(quote
        circ = Circuit()
        r1 = Resistor(1e+3)
        i_DC = DCCurrentSource(40e-3)
        connect!(circ, i_DC.pOut, r1.p1)
        connect!(circ, i_DC.pIn, r1.p2)
        connect!(circ, i_DC.pIn, circ.gnd)
    end)
end

# circuit with open ends
# o--R1--V1--R2--o
# this is not a "degenerate" circuit - it shouldn't break the solver
# but it currently does -> we need to add a zero-current condition
# at floating ports on two port compoennts
macro circuit5()

    esc(quote
        circ = Circuit()
        r1 = Resistor(10e+3)
        r2 = Resistor(15e+3)
        v_DC = DCVoltageSource(5.)
        connect!(circ, r1.p2, v_DC.pLow)
        connect!(circ, v_DC.pHigh, r2.p1)
        connect!(circ, circ.gnd, v_DC.pLow)
    end)
end

# simple non-linear circuit with a diode
macro circuit6()

    esc(quote
        circ = Circuit()
        r1 = Resistor(50.)
        d1 = Diode(1e-11, 0.026, 1.)
        v_DC = DCVoltageSource(5.)
        connect!(circ, r1.p1, v_DC.pHigh)
        connect!(circ, r1.p2, p1(d1))
        connect!(circ, p2(d1), v_DC.pLow)
        connect!(circ, v_DC.pLow, circ.gnd)
    end)
end

# a simple voltage limiter, with two diodes
macro circuit7()

    esc(quote
        circ = Circuit()
        r1 = Resistor(0.5e+3)
        d1 = Diode(1e-11, 0.026, 1.)
        d2 = Diode(1e-11, 0.026, 1.)
        v_DC = DCVoltageSource(15.)
        connect!(circ, v_DC.pLow, circ.gnd)
        connect!(circ, p1(r1), v_DC.pHigh)
        connect!(circ, p2(r1), p1(d1))
        connect!(circ, p2(r1), p2(d2))
        connect!(circ, p2(d1), v_DC.pLow)
        connect!(circ, p1(d2), v_DC.pLow)
    end)
end

# simple NPN BJT circuit
macro circuit8()
    
    esc(quote
        circ = Circuit()
        rc = Resistor(1e+3)
        rb = Resistor(40e+3)
        vcc = DCVoltageSource(10.)
        q1 = NPN()
        connect!(circ, circ.gnd, vcc.pLow)
        connect!(circ, vcc.pHigh, rc.p1)
        connect!(circ, rc.p2, rb.p1, "Vout")
        connect!(circ, rc.p2, q1.pC)
        connect!(circ, rb.p2, q1.pB)
        connect!(circ, circ.gnd, q1.pE)
    end)
end

# low pass RC filter
macro circuit9()
    
    esc(quote
        circ = Circuit()
        # note: not a DC voltage source!
        vin = VoltageSource(:(sin(1000*t)))
        r1 = Resistor(100e+3)
        c1 = Capacitor(10e-6)
        connect!(circ, vin.pHigh, r1.p1)
        connect!(circ, r1.p2, c1.p1, "Vout")
        connect!(circ, c1.p2, vin.pLow)
        connect!(circ, vin.pLow, circ.gnd)
    end)
end
