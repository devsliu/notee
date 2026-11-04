package main

type ResultCode struct {
	Value   int
	Message string
}

func (rc ResultCode) with(message string) ResultCode {
	return ResultCode{rc.Value, message}
}

func ResultCodeError(rc *ResultCode, defaultRC ResultCode, err error) ResultCode {
	if err != nil {
		if rc != nil {
			return *rc
		}
		return defaultRC
	}
	return ResultSuccess
}

var (
	ResultSuccess             = ResultCode{200, "OK"}
	ResultErrorAuth           = ResultCode{401, "unauthorized"}
	ResultErrorRecordConflict = ResultCode{531, "record conflict"}
	ResultErrorDatabase       = ResultCode{532, "database error"}
	ResultErrorRecordNotFound = ResultCode{533, "record not found"}
	ResultErrorParams         = ResultCode{534, "invalid parameter"}
	ResultErrorRecordSave     = ResultCode{535, "record save error"}
	ResultErrorFileNotFound   = ResultCode{536, "file not found"}
	ResultErrorNeedFullSync   = ResultCode{537, "need full sync"} // client version < purgedVersion, must do a full pull

	ResultErrorUserPasswordError = ResultCode{561, "invalid username or password"}
	ResultErrorTokenExpired      = ResultCode{562, "token near expiry, auto-relogin possible"}
)
