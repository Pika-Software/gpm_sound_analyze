local Sizes = {
    [0] = FFT_256,      -- 0 - 128 levels
    [1] = FFT_512,      -- 1 - 256 levels
    [2] = FFT_1024,     -- 2 - 512 levels
    [3] = FFT_2048,     -- 3 - 1024 levels
    [4] = FFT_4096,     -- 4 - 2048 levels
    [5] = FFT_8192,     -- 5 - 4096 levels
    [6] = FFT_16384,    -- 6 - 8192 levels
    [7] = FFT_32768     -- 7 - 16384 levels
}

local sound_analyze = {}
sound_analyze.__index = sound_analyze

function SoundAnalyze()
    return setmetatable({
        -- FFT
        FFT = {},
        Size = Sizes[6],

        -- FFT History
        History = {},
        HistorySize = 5,
        HistoryDelay = 0,
        HistoryMaxSize = 30,

        -- Bass
        Bass = 0,
        BassSize = 1000,

        -- Spectrum
        Spectrum = {},
        SpectrumAverage = {},

    }, sound_analyze )
end

local assert = assert
local type = type

do
    local tostring = tostring
    function sound_analyze:__tostring()
        return "SoundAnalyze channel: " .. tostring( self.audio )
    end
end

function sound_analyze:GetAudio()
    return self.audio
end

do

    local IsValid = IsValid
    local good_states = {
        [1] = true,
        [2] = true,
        [3] = true
    }

    function sound_analyze:IsValid()
        local audio = self:GetAudio()
        if IsValid( audio ) then
            return good_states[ audio:GetState() ] or false
        end

        return false
    end
end

function sound_analyze:SetAudio( channel )
    assert( type( channel ) == "IGModAudioChannel", "bad argument #1 (IGModAudioChannel expected)")
    self.audio = channel

    hook.Add("Think", self, function( self )
       -- print( self:GetAudio(), self:GetAudio():GetState(), self:GetAudio():GetVolume(), self, IsValid( self ) )
        self:GetAudio():FFT( self.FFT, self.Size )
        self:BassThink( self.BassSize )
        self:FFTHistoryThink()
        self:GetBeat()
    end)
end

do

    local CurTime = CurTime
    local table_insert = table.insert
    local table_remove = table.remove

    -- Size
    function sound_analyze:SetSize( size )
        assert( type( size ) == "number", "bad argument #1 (number expected)")
        self.Size = size
    end

    function sound_analyze:GetSize()
        return self.Size
    end

    function sound_analyze:GetFFT()
        return self.FFT
    end

    function sound_analyze:FFTHistorySetDelay( time )
        assert( type( time ) == "number", "bad argument #1 (number expected)")
        self.HistoryDelay = time
    end

    function sound_analyze:FFTHistorySetMaxSize( size )
        assert( type( size ) == "number", "bad argument #1 (number expected)")
        self.HistoryMaxSize = size
    end

    local math_averageList = math.averageList
    function sound_analyze:FFTHistoryThink()
        local avgtbl = {}
        for i = 1, self.HistorySize do
            avgtbl[i] = {}
        end

        for i = 1, 1528 do
            if i >= 1 and i <= 32 then
                table_insert( avgtbl[1], self.FFT[i] )
            end

            if i >= 32 and i <= 56 then
                table_insert( avgtbl[2], self.FFT[i] )
            end

            if i >= 56 and i <= 328 then
                table_insert( avgtbl[3], self.FFT[i] )
            end

            if i >= 528 and i <= 1528 then
                table_insert( avgtbl[4], self.FFT[i] )
            end

        end

        avgtbl[5] = self.FFT

        for i = 1, self.HistorySize do
            if (self.History[i] == nil) then
                self.History[i] = {}
            end

            table_insert( self.History[i], math_averageList( avgtbl[i] ) )

            if #self.History[i] > self.HistoryMaxSize then
                table_remove( self.History[i], 1 )
            end

        end

    end

end


do

    function sound_analyze:GetBass( size )
        return self.Bass or 0
    end

    local math_max = math.max
    function sound_analyze:BassThink( size )
        self.BassSize = size
        self.Bass = 0
        for i = 1, self.BassSize do
            if (self.FFT[i] == nil) then continue end
            self.Bass = math_max( self.Bass, self.FFT[i] * 170 or 0.01 ) or 0
        end
    end

    function sound_analyze:GetBassSize()
        return self.BassSize
    end

end

do

    local math_average = math.average
    local table_insert = table.insert
    local math_averageList = math.averageList
    local table_remove = table.remove

    local multiplier = 1.1
    local counter = 0
    function sound_analyze:GetBeat()
        local spectbl = {}
        for i = 1, self.HistorySize do
            self.SpectrumAverage[i] = 0
            self.Spectrum[i] = 0
            spectbl[i] = {}
        end

        if #self.History > 0 then

            for i = 1, #self.FFT do

                -- if i >= 1 and i <= 32 then
                --     self.Spectrum[1] = math.max(self.Spectrum[1]  , self.FFT[i])
                -- end

                if i >= 1 and i <= 32 then
                    table_insert( spectbl[1], self.FFT[i] )
                end

                if i >= 32 and i <= 56 then
                    table_insert( spectbl[2], self.FFT[i] )
                end

                if i >= 56 and i <= 328 then
                    table_insert( spectbl[3], self.FFT[i] )
                end

                if i >= 528 and i <= 1528 then
                    table_insert( spectbl[4], self.FFT[i] )
                end

            end

            spectbl[5] = self.FFT
            self.Spectrum[1] = math_averageList( spectbl[1] ) / 1.01

            for i = 2, 5 do
                self.Spectrum[i] = math_averageList( spectbl[i] ) / multiplier
            end

            for i = 1, #self.History[1] - 2 do
                self.SpectrumAverage[1] = math_average( self.SpectrumAverage[1], self.History[1][i] )
            end

            for i = 1, #self.History[2] - 2 do
                self.SpectrumAverage[2] = math_average( self.SpectrumAverage[2], self.History[2][i] )
            end

            for i = 1, #self.History[3] - 3 do
                self.SpectrumAverage[3] = math_average( self.SpectrumAverage[3], self.History[3][i] )
            end

            for i = 1, #self.History[4] - 5 do
                self.SpectrumAverage[4] = math_average( self.SpectrumAverage[4], self.History[4][i] )
            end

            for i = 1, #self.History[5] - 5 do
                self.SpectrumAverage[5] = math_average( self.SpectrumAverage[5], self.History[5][i] )
            end

            self.isBass = self.Spectrum[1] >= self.SpectrumAverage[1] * multiplier and self.Spectrum[1] - self.SpectrumAverage[1] != 0
            self.isOverBass = self.Spectrum[1] >= self.SpectrumAverage[1] * multiplier * 6 and self.Spectrum[1] - self.SpectrumAverage[1] != 0
            self.isLow = self.Spectrum[2] >= self.SpectrumAverage[2] * multiplier and self.Spectrum[2] - self.SpectrumAverage[2] != 0
            self.isMiddle = self.Spectrum[3] >= self.SpectrumAverage[3] * multiplier and self.Spectrum[3] - self.SpectrumAverage[3] != 0
            self.isHige = self.Spectrum[4] >= self.SpectrumAverage[4] * multiplier and self.Spectrum[4] - self.SpectrumAverage[4] != 0
            self.isAllBass = self.Spectrum[5] >= self.SpectrumAverage[5] * multiplier and self.Spectrum[5] - self.SpectrumAverage[5] != 0

            if self.isBass and (self.OnBeatBass ~= nil) then
                self:OnBeatBass()
            end

            if self.isOverBass and (self.OnOverBass ~= nil) then
                self:OnOverBass()
            end

            if self.isLow and (self.OnBeatLow ~= nil) then
                self:OnBeatLow()
            end

            if self.isMiddle and (self.OnBeatMiddle ~= nil) then
                self:OnBeatMiddle()
            end

            if self.isHige and (self.OnBeatHige ~= nil) then
                self:OnBeatHige()
            end

            if self.isAllBass and (self.OnAllBeat ~= nil) then
                self:OnAllBeat()
            end

            if (self.isBass or self.isLow or self.isOverBass or self.isHige)  then
                counter = counter + 1
                if counter>= 4 then
                    if (self.OnBeat ~= nil) then
                        self:OnBeat()
                    end
                    counter = 0
                end
            end


        end

    end

    function sound_analyze:DebugBeat()
        return self.isBass, self.isLow, self.isMiddle, self.isHige, self.isAllBass
    end

    function sound_analyze:DebugBPM()
        return self.BPM, self.BPMHistory, self.OldCurTime
    end

    function  sound_analyze:BPM()
        local buffer = buffer or {}
        if self.isBass or self.isLow or self.isMiddle or self.isHige or self.isAllBass or self.isOverBass then
            table_insert(buffer,true)
        else
            table_insert(buffer,false)
        end

        if #buffer > 100 then
            table_remove( buffer, 1 )
        end
    end

end

