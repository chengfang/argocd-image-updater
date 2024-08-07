// Code generated by mockery v2.43.2. DO NOT EDIT.

package mocks

import (
	mock "github.com/stretchr/testify/mock"

	time "time"
)

// Limiter is an autogenerated mock type for the Limiter type
type Limiter struct {
	mock.Mock
}

// Take provides a mock function with given fields:
func (_m *Limiter) Take() time.Time {
	ret := _m.Called()

	if len(ret) == 0 {
		panic("no return value specified for Take")
	}

	var r0 time.Time
	if rf, ok := ret.Get(0).(func() time.Time); ok {
		r0 = rf()
	} else {
		r0 = ret.Get(0).(time.Time)
	}

	return r0
}

// NewLimiter creates a new instance of Limiter. It also registers a testing interface on the mock and a cleanup function to assert the mocks expectations.
// The first argument is typically a *testing.T value.
func NewLimiter(t interface {
	mock.TestingT
	Cleanup(func())
}) *Limiter {
	mock := &Limiter{}
	mock.Mock.Test(t)

	t.Cleanup(func() { mock.AssertExpectations(t) })

	return mock
}
