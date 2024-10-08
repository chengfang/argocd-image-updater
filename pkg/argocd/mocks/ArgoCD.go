// Code generated by mockery v2.43.0. DO NOT EDIT.

package mocks

import (
	application "github.com/argoproj/argo-cd/v2/pkg/apiclient/application"

	context "context"

	mock "github.com/stretchr/testify/mock"

	v1alpha1 "github.com/argoproj/argo-cd/v2/pkg/apis/application/v1alpha1"
)

// ArgoCD is an autogenerated mock type for the ArgoCD type
type ArgoCD struct {
	mock.Mock
}

// GetApplication provides a mock function with given fields: ctx, appName
func (_m *ArgoCD) GetApplication(ctx context.Context, appName string) (*v1alpha1.Application, error) {
	ret := _m.Called(ctx, appName)

	if len(ret) == 0 {
		panic("no return value specified for GetApplication")
	}

	var r0 *v1alpha1.Application
	var r1 error
	if rf, ok := ret.Get(0).(func(context.Context, string) (*v1alpha1.Application, error)); ok {
		return rf(ctx, appName)
	}
	if rf, ok := ret.Get(0).(func(context.Context, string) *v1alpha1.Application); ok {
		r0 = rf(ctx, appName)
	} else {
		if ret.Get(0) != nil {
			r0 = ret.Get(0).(*v1alpha1.Application)
		}
	}

	if rf, ok := ret.Get(1).(func(context.Context, string) error); ok {
		r1 = rf(ctx, appName)
	} else {
		r1 = ret.Error(1)
	}

	return r0, r1
}

// ListApplications provides a mock function with given fields:
func (_m *ArgoCD) ListApplications(labelSelector string) ([]v1alpha1.Application, error) {
	ret := _m.Called()

	if len(ret) == 0 {
		panic("no return value specified for ListApplications")
	}

	var r0 []v1alpha1.Application
	var r1 error
	if rf, ok := ret.Get(0).(func() ([]v1alpha1.Application, error)); ok {
		return rf()
	}
	if rf, ok := ret.Get(0).(func() []v1alpha1.Application); ok {
		r0 = rf()
	} else {
		if ret.Get(0) != nil {
			r0 = ret.Get(0).([]v1alpha1.Application)
		}
	}

	if rf, ok := ret.Get(1).(func() error); ok {
		r1 = rf()
	} else {
		r1 = ret.Error(1)
	}

	return r0, r1
}

// UpdateSpec provides a mock function with given fields: ctx, spec
func (_m *ArgoCD) UpdateSpec(ctx context.Context, spec *application.ApplicationUpdateSpecRequest) (*v1alpha1.ApplicationSpec, error) {
	ret := _m.Called(ctx, spec)

	if len(ret) == 0 {
		panic("no return value specified for UpdateSpec")
	}

	var r0 *v1alpha1.ApplicationSpec
	var r1 error
	if rf, ok := ret.Get(0).(func(context.Context, *application.ApplicationUpdateSpecRequest) (*v1alpha1.ApplicationSpec, error)); ok {
		return rf(ctx, spec)
	}
	if rf, ok := ret.Get(0).(func(context.Context, *application.ApplicationUpdateSpecRequest) *v1alpha1.ApplicationSpec); ok {
		r0 = rf(ctx, spec)
	} else {
		if ret.Get(0) != nil {
			r0 = ret.Get(0).(*v1alpha1.ApplicationSpec)
		}
	}

	if rf, ok := ret.Get(1).(func(context.Context, *application.ApplicationUpdateSpecRequest) error); ok {
		r1 = rf(ctx, spec)
	} else {
		r1 = ret.Error(1)
	}

	return r0, r1
}

// NewArgoCD creates a new instance of ArgoCD. It also registers a testing interface on the mock and a cleanup function to assert the mocks expectations.
// The first argument is typically a *testing.T value.
func NewArgoCD(t interface {
	mock.TestingT
	Cleanup(func())
}) *ArgoCD {
	mock := &ArgoCD{}
	mock.Mock.Test(t)

	t.Cleanup(func() { mock.AssertExpectations(t) })

	return mock
}
